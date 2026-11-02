"""Train one neural cellular automaton (NCA) texture for PuffyPond's brushes.

Follows the official PyTorch notebook of "Self-Organising Textures" (Niklasson, Mordvintsev, Randazzo, Levin,
Distill 2021): github.com/google-research/self-organising-systems/notebooks/texture_nca_pytorch.ipynb

  state          12 channels, no clamp (an overflow loss keeps them near -1..1); rgb = state[0:3] + 0.5
  perception     4 fixed 3x3 kernels per channel (identity, Sobel-x, Sobel-y, Laplacian), raw (not rescaled)
  network        1x1 conv 48 -> 96 (+bias), ReLU, 1x1 conv 96 -> 12 (no bias, starts at zero)
  update         state += dt * delta * mask, mask = each cell fires with probability fire_rate (0.5)
  loss           frozen VGG16 features of the result vs the target, sliced optimal transport, + overflow loss
  training       pool of 256 states, batch 4, 32..95 steps, a fresh zero seed every 8th iteration,
                 Adam 1e-3 (x0.3 at 20% and 40% of the run), per-tensor gradient normalisation

Perception layout is channel-major: value index = channel * 4 + kernel (0 id, 1 sobel-x, 2 sobel-y, 3 laplacian).
The texture wraps at its edges. --stride/--jitter (off by default) read the neighbours at a larger, per-pixel
jittered stride with bilinear filtering, as Splash Canvas does; that is not part of the notebook.

Usage:
  python train_nca.py --target texture.jpg --out runs/bristle
  python train_nca.py --target texture.jpg --out runs/bristle --gray
"""
import argparse
import json
import random
from pathlib import Path

import numpy as np
import torch
import torch.nn as nn
import torch.nn.functional as F
import torchvision
from PIL import Image

PAD = 3  # circular padding for the strided path: covers stride 2 * 1.25 jitter plus the bilinear tap

# 3x3 kernels, row = dy (-1, 0, 1), column = dx (-1, 0, 1). Raw values, as in the notebook.
KERNELS = {
    "sobel_x": np.array([[-1, 0, 1], [-2, 0, 2], [-1, 0, 1]], np.float32),
    "sobel_y": np.array([[-1, -2, -1], [0, 0, 0], [1, 2, 1]], np.float32),
    "laplacian": np.array([[1, 2, 1], [2, -12, 2], [1, 2, 1]], np.float32),
}
IDENT = np.array([[0, 0, 0], [0, 1, 0], [0, 0, 0]], np.float32)


def pick_device():
    if torch.backends.mps.is_available():
        return torch.device("mps")
    if torch.cuda.is_available():
        return torch.device("cuda")
    return torch.device("cpu")


class NCA(nn.Module):
    def __init__(self, chn=12, hidden=96, stride=1.0, jitter=0.0, dt=1.0):
        super().__init__()
        self.chn, self.hidden = chn, hidden
        self.stride, self.jitter, self.dt = stride, jitter, dt
        self.w1 = nn.Conv2d(chn * 4, hidden, 1)
        self.w2 = nn.Conv2d(hidden, chn, 1, bias=False)
        self.w2.weight.data.zero_()  # start as "do nothing"
        filters = np.stack([IDENT, KERNELS["sobel_x"], KERNELS["sobel_y"], KERNELS["laplacian"]])
        self.register_buffer("filters", torch.from_numpy(filters)[:, None])  # (4, 1, 3, 3)

    @property
    def plain(self):
        """Neighbours exactly one texel away: the notebook's depthwise convolution."""
        return self.stride == 1.0 and self.jitter == 0.0

    def perceive_plain(self, x):
        b, c, h, w = x.shape
        y = F.pad(x.reshape(b * c, 1, h, w), [1, 1, 1, 1], "circular")
        return F.conv2d(y, self.filters).reshape(b, c * 4, h, w)

    def perceive_strided(self, x, s):
        b, c, h, w = x.shape
        xp = F.pad(x, (PAD,) * 4, mode="circular")
        hp, wp = h + 2 * PAD, w + 2 * PAD
        ys, xs = torch.meshgrid(torch.arange(h, device=x.device), torch.arange(w, device=x.device), indexing="ij")
        px = (xs + PAD + 0.5).float()[None]
        py = (ys + PAD + 0.5).float()[None]
        acc = [torch.zeros_like(x) for _ in range(3)]
        for dy in (-1, 0, 1):
            for dx in (-1, 0, 1):
                if dx == 0 and dy == 0:
                    tap = x
                else:
                    gx = 2.0 * (px + s[:, 0] * dx) / wp - 1.0
                    gy = 2.0 * (py + s[:, 0] * dy) / hp - 1.0
                    tap = F.grid_sample(xp, torch.stack([gx, gy], dim=-1), mode="bilinear",
                                        padding_mode="border", align_corners=False)
                for i, k in enumerate(("sobel_x", "sobel_y", "laplacian")):
                    wgt = float(KERNELS[k][dy + 1, dx + 1])
                    if wgt != 0.0:
                        acc[i] = acc[i] + wgt * tap
        return torch.stack([x, acc[0], acc[1], acc[2]], dim=2).reshape(b, c * 4, h, w)

    def step(self, x, s, fire_rate):
        y = self.perceive_plain(x) if self.plain else self.perceive_strided(x, s)
        y = self.w2(torch.relu(self.w1(y)))
        if fire_rate < 1.0:
            y = y * (torch.rand(x.shape[0], 1, x.shape[2], x.shape[3], device=x.device) < fire_rate).float()
        return x + self.dt * y

    def forward(self, x, steps, fire_rate=0.5):
        s = None
        if not self.plain:  # per-pixel stride, fixed for the whole rollout (the shader hashes the pixel coordinate)
            r = torch.rand(x.shape[0], 1, x.shape[2], x.shape[3], device=x.device) - 0.5
            s = self.stride * (1.0 + 2.0 * self.jitter * r)
        for _ in range(steps):
            x = self.step(x, s, fire_rate)
        return x

    def seed(self, n, size, device):
        return torch.zeros(n, self.chn, size, size, device=device)


class StyleLoss:
    """Sliced optimal transport between frozen VGG16 features (the notebook's loss).

    Features: the raw pixels plus the activations after conv1_1, conv2_1, conv3_1, conv4_1 and conv5_1."""
    LAYERS = (1, 6, 11, 18, 25)

    def __init__(self, target, device, proj_n=32):
        self.vgg = torchvision.models.vgg16(weights=torchvision.models.VGG16_Weights.IMAGENET1K_V1).features
        self.vgg = self.vgg[: self.LAYERS[-1] + 1].eval().to(device)
        for p in self.vgg.parameters():
            p.requires_grad_(False)
        self.mean = torch.tensor([0.485, 0.456, 0.406], device=device).view(1, 3, 1, 1)
        self.std = torch.tensor([0.229, 0.224, 0.225], device=device).view(1, 3, 1, 1)
        self.proj_n = proj_n
        with torch.no_grad():
            self.target = self.features(target)

    def features(self, rgb):
        x = (rgb - self.mean) / self.std
        out = [x.flatten(2)]
        for i, layer in enumerate(self.vgg):
            x = layer(x)
            if i in self.LAYERS:
                out.append(x.flatten(2))
        return out

    def ot(self, source, target):
        ch, n = source.shape[-2:]
        proj = F.normalize(torch.randn(ch, self.proj_n, device=source.device), dim=0)
        src = torch.einsum("bcn,cp->bpn", source, proj).sort()[0]
        tgt = torch.einsum("bcn,cp->bpn", target, proj).sort()[0]
        tgt = F.interpolate(tgt, n, mode="nearest")
        return (src - tgt).square().sum()

    def __call__(self, rgb):
        return sum(self.ot(s, t) for s, t in zip(self.features(rgb), self.target))


def to_rgb(state):
    """The notebook's convention: the visible channels are centred on 0, so add 0.5."""
    return state[:, :3] + 0.5


def load_target(path, size, gray, device):
    img = Image.open(path).convert("RGB")
    side = min(img.size)  # centre square crop
    left, top = (img.width - side) // 2, (img.height - side) // 2
    img = img.crop((left, top, left + side, top + side)).resize((size, size), Image.LANCZOS)
    t = torch.from_numpy(np.asarray(img)).float().div(255.0).permute(2, 0, 1)[None]
    if gray:
        t = t.mean(1, keepdim=True).expand(-1, 3, -1, -1).contiguous()
    return t.to(device)


def export(model, out_dir, args):
    """nca.bin: float32 little-endian: w1 [hidden][chn*4], b1 [hidden], w2 [chn][hidden] (no bias)."""
    chn, hidden = model.chn, model.hidden
    w1 = model.w1.weight.detach().cpu().reshape(hidden, chn * 4).numpy()
    b1 = model.w1.bias.detach().cpu().numpy()
    w2 = model.w2.weight.detach().cpu().reshape(chn, hidden).numpy()
    blob = np.concatenate([w1.ravel(), b1, w2.ravel()]).astype("<f4")
    (out_dir / "nca.bin").write_bytes(blob.tobytes())
    meta = {
        "channels": chn,
        "hidden": hidden,
        "floatCount": int(blob.size),
        "layout": ["w1[hidden][channels*4]", "b1[hidden]", "w2[channels][hidden] (no bias)"],
        "perception": "value index = channel * 4 + kernel; kernels: identity, sobel_x, sobel_y, laplacian (raw, not rescaled)",
        "kernels": {k: v.tolist() for k, v in KERNELS.items()},
        "stride": args.stride,
        "strideJitter": args.jitter,
        "dt": args.dt,
        "fireRate": args.fire_rate,
        "statePacking": "rgb = state[0:3] + 0.5; state += dt * delta * fireMask; no clamp",
        "seed": "zeros",
        "gray": args.gray,
        "wrap": "circular",
    }
    (out_dir / "nca.json").write_text(json.dumps(meta, indent=2))


@torch.no_grad()
def preview(model, out_dir, name, device, fire_rate, size=256, steps=200):
    model.eval()
    x = model(model.seed(1, size, device), steps, fire_rate)
    torchvision.utils.save_image(to_rgb(x).clamp(0.0, 1.0), out_dir / name)
    model.train()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--target", required=True, help="texture image (centre square crop is used)")
    ap.add_argument("--out", required=True, help="output directory")
    ap.add_argument("--size", type=int, default=128, help="training resolution")
    ap.add_argument("--channels", type=int, default=12)
    ap.add_argument("--hidden", type=int, default=96)
    ap.add_argument("--iters", type=int, default=5000)
    ap.add_argument("--batch", type=int, default=4)
    ap.add_argument("--pool", type=int, default=256)
    ap.add_argument("--steps-min", type=int, default=32)
    ap.add_argument("--steps-max", type=int, default=95, help="inclusive")
    ap.add_argument("--lr", type=float, default=1e-3)
    ap.add_argument("--stride", type=float, default=1.0, help="neighbour stride in texels (not in the notebook)")
    ap.add_argument("--jitter", type=float, default=0.0, help="per-pixel stride jitter, +- fraction (not in the notebook)")
    ap.add_argument("--dt", type=float, default=1.0)
    ap.add_argument("--fire-rate", type=float, default=0.5, help="chance a cell updates each step")
    ap.add_argument("--gray", action="store_true", help="train on luminance so the splat colour can tint it")
    ap.add_argument("--preview-every", type=int, default=500)
    ap.add_argument("--seed", type=int, default=0)
    args = ap.parse_args()

    random.seed(args.seed)
    torch.manual_seed(args.seed)
    device = pick_device()
    out_dir = Path(args.out)
    out_dir.mkdir(parents=True, exist_ok=True)
    print(f"device {device}")

    target = load_target(args.target, args.size, args.gray, device)
    torchvision.utils.save_image(target, out_dir / "target.png")
    style = StyleLoss(target, device)

    model = NCA(args.channels, args.hidden, args.stride, args.jitter, args.dt).to(device)
    print(f"parameters {sum(p.numel() for p in model.parameters())}")
    opt = torch.optim.Adam(model.parameters(), lr=args.lr)
    sched = torch.optim.lr_scheduler.MultiStepLR(opt, [int(args.iters * 0.2), int(args.iters * 0.4)], 0.3)
    pool = model.seed(args.pool, args.size, device)

    for it in range(1, args.iters + 1):
        idx = torch.randperm(args.pool)[: args.batch].to(device)
        x = pool[idx].clone()
        if (it - 1) % 8 == 0:
            x[0] = model.seed(1, args.size, device)[0]  # keep fresh seeds coming
        x = model(x, random.randint(args.steps_min, args.steps_max), args.fire_rate)

        overflow = (x - x.clamp(-1.0, 1.0)).abs().sum()
        loss = style(to_rgb(x)) + overflow
        opt.zero_grad()
        loss.backward()
        for p in model.parameters():  # per-tensor gradient normalisation, as in the notebook
            p.grad = p.grad / (p.grad.norm() + 1e-8)
        opt.step()
        sched.step()
        pool[idx] = x.detach()

        if it % 50 == 0:
            print(f"iter {it}/{args.iters}  loss {loss.item():.2f}  overflow {overflow.item():.2f}")
        if it % args.preview_every == 0 or it == args.iters:
            preview(model, out_dir, f"preview_{it:05d}.png", device, args.fire_rate)
            torch.save(model.state_dict(), out_dir / "model.pt")
            export(model, out_dir, args)

    print(f"done. weights: {out_dir / 'nca.bin'}  meta: {out_dir / 'nca.json'}")


if __name__ == "__main__":
    main()
