# Guide voice clips

The tracing guide says things like "Yuk mulai dari sini! Naik ke atas ya!". Every sentence it can say is listed in
`units.txt` (one per line; a test keeps the list in sync with the code).

- With no audio files the app reads the lines with the device's Indonesian voice (robotic).
- With one clip per line in `PuffyPond/Voice/` (`guide-<slug>.mp3`, `.m4a` or `.wav`) it plays the clips instead,
  and the voice menu says so. Xcode picks the files up on its own (the folder is part of the synced target).

Make the clips with `make_clips.py` (see its header), or record the lines yourself and name each file
`guide-` + the line in lowercase with every run of other characters turned into `-`
(e.g. `Ayo, geser ke kanan!` → `guide-ayo-geser-ke-kanan.mp3`). If one line of a direction has no clip, that whole
direction falls back to the device voice, so make the whole set.
