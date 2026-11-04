<!-- prd-progress
role: co-maker (metadata, background, success-metrics); executor (rest)
pace: normal
prd-language: English
sections:
  metadata: done
  background: done
  success-metrics: done
  documentation: done
  timeline: done
  scope: done
  discussions: done
  competitive-analysis: done
  product-requirement: done
  acceptance-criteria: done
  event-tracker: done
  test-cases: done
gaps:
- Epic link
- QA owner
- Literature review sources
- Play motivation target
- Trial period length
-->
<!-- Format rules for scripts/build_docx.py:
  - "# " is the project name. "## " is a section. "### " is a sub-heading.
  - In tables, a cell containing only ^ merges into the cell above.
  - Use <br> for a line break inside a table cell.
  - HTML comments (like this one) are not exported.
  - Status values: todo, in-progress, done, skipped. -->

# Motale (Puffy Pond)

Disclaimer: filled by AI in Executor role. Every item marked (*) is a prediction. Validate and check each one before sharing or acting on this PRD.

| | |
|---|---|
| **Target release** | November 2026 (around 17 Nov 2026, 2 weeks from 3 Nov 2026) |
| **Epic** | [TBD: epic link] |
| **Document status** | Draft |
| **Document owner** | @Rizki Hidayatul Laeli |
| **Designer** | @Adri Maulana Putra, @Graceilla Natasya |
| **Tech lead** | @Filbert Naldo Wijaya |
| **Technical writers** | @Rizki Hidayatul Laeli |
| **QA** | [TBD: QA] |

## Background

### What is the background that initiates this project?
Children with cerebral palsy (CP) need regular upper-limb motor exercise, including at home. Our research found two things: the exercise feels boring and repetitive, so children are not motivated, and parents and therapists find it hard to track a child's movement progress outside therapy sessions. Motale answers both with a drawing game controlled by hand movements in front of an iPad camera, for children aged 10–12 with CP (MACS I–II).

### What are the problems? Has the problem been verified?
The problems are:
- **Boring exercise:** upper-limb motor exercise is repetitive, so children with CP aged 10–12 are not motivated to practise at home.
- **Invisible progress:** parents don't know how their child's movement develops between therapy sessions, so it is hard for them to report the child's condition to the therapist.
- **Limited movement variety:** home exercise rarely trains both hands at once (bilateral) or wide-range movements.
- **Lack of stimulus:** children move more willingly with cheerful music and bright, high-contrast visuals, but regular exercise has neither.

What we know so far: all four problems came from interviews with 2 rehabilitation doctors, 2 therapists, and 3 parents of children with CP, direct observation at World Cerebral Palsy Day 2026, and a literature review [TBD: journal titles or links].

What we have not known:
- Whether drawing with hand movements makes children exercise longer than regular exercise.
- Whether parents actually open the report regularly.

### What are the objectives?
- Children exercise their upper limbs more often and for longer because the activity feels like play.
- Children make more bilateral and wide-range movements while playing.
- Parents can see and understand their child's movement progress between therapy sessions.
- Parents can bring report data to the therapist as discussion material.

## Success Metrics

| Objective | Goal | Metric |
|---|---|---|
| Children exercise more often and for longer | Play duration | Average seconds on the Canvas page per session (from the sidecar). Target: ≥ 10 minutes per session |
| ^ | Play motivation | Child keeps playing without being told, from team observation or parent report. Target: [TBD: how many of N children] |
| Children make more bilateral and wide-range movements | Movement range | Filled heatmap area divided by canvas area per session. Target: ≥ 50% |
| ^ | Level progress | A Medium-level template is unlocked within the trial period [TBD: period length] |
| Parents can see and understand their child's movement progress | Report understanding | Parents can explain Highest ROM, heatmap, and hand dominance without help. Target: ≥ 2 of 3 parents |
| ^ | Report usage | Parents open the Report page at least once a week, from parent report at follow-up |
| Parents can bring report data to the therapist | Report taken to therapist | Parents show the report to the therapist at least once during the trial period |
| ^ | Clinically useful report | A rehab doctor or therapist names at least 1 metric in the report they can use for evaluation |

## Documentation

| Document | Link |
|---|---|
| "Motale for Expert" deck (Little Crew, Nov 2026) | PDF file `deck_c7_for expert.pdf`, stored in the team folder (*) |
| Feature and acceptance criteria table per epic | `PuffyPond2/docs/PuffyPond_PRD.xlsx` (*) |
| App README (how to run, page flow, controls) | `PuffyPond2/README.md` (*) |
| App flow update plan (1 Nov 2026) | `PuffyPond2/docs/superpowers/plans/2026-11-01-app-flow-update.md` (*) |
| PuffyPond2 code repository (Swift, Xcode 26) | Git repo link, to be added by @tech-lead (*) |
| Interview synthesis: 2 rehab doctors, 2 therapists, 3 parents | Interview synthesis document, to be created by @product-owner (*) |
| World Cerebral Palsy Day 2026 observation notes | Observation notes document, to be created by @product-owner (*) |
| Literature review on gamified motor therapy for children with CP | List of journals the team has read, collected by @product-owner (*) |
| UI design (Home, Canvas, Gallery, Report) | Figma file, shared by @designer (*) |

## Timeline

| Milestones | Finished by |
|---|---|
| **Finalize VPC** | 4 Nov 2026 (*) |
| **Solution Concept** | 5 Nov 2026 (*) |
| **Wireframe** | 6 Nov 2026 (*) |
| **Lo-Fi** | 9 Nov 2026 (*) |
| **Hi-Fi** | 11 Nov 2026 (*) |
| **1st Prototype** | 14 Nov 2026 (*) |
| **Trial with children, parents, and therapists** | 16 Nov 2026 (*) |
| **Release / Apple review** | 17 Nov 2026 (*) |

## Scope

- Interface: iPad (landscape, primary) and Mac, using the front camera (*)
- Language: English UI for v1 (*)
- Country to launch: Indonesia (*)
- Other constraints: all data stays on the device, with no network and no accounts; movement numbers are 2D camera estimates, not clinical measurements (*)

In Scope for v1 (MVP):
- Drawing with hand movements: fist to paint, open hand to move, both hands can paint at once (problems: boring exercise, limited movement variety) (*)
- Changing color and tool by rubbing paint pots and tool bubbles at the canvas edges, so the child reaches sideways (problem: limited movement variety) (*)
- Easy, Medium, Hard templates with progressive unlock and a Daily Quest (problem: boring exercise) (*)
- Cheerful music and sound feedback that respond to movement (problem: lack of stimulus) (*)
- 3D museum gallery navigated with a paddle gesture, plus a 2D gallery (problem: boring exercise) (*)
- Daily report for parents: Highest ROM, heatmap, hand dominance (problem: invisible progress) (*)

Out of Scope for v1:
- Audio that responds to paintings in the gallery: needs new sound design, not in the code yet, and does not test the core hypothesis (*)
- Arranging frame positions in the gallery: needs a new 3D edit mode; automatic ordering is enough for v1 (*)
- Accounts, cloud sync, and online report sharing: adds privacy risk for children's data and needs a backend (*)
- Therapist dashboard: in v1 parents show the report on the iPad (*)
- Validated clinical measurement: needs a validation study against standard measuring tools (*)

Core Hypothesis: We believe children with CP aged 10–12 (MACS I–II) will exercise their upper limbs longer if the exercise is drawing with their hands in front of a camera with music, and we'll know when the average time on the Canvas page reaches ≥ 10 minutes per session. (*)

## Discussions (Optional)

| Question | Answer | Date Answered |
|---|---|---|
| How long is the trial period with children and parents? | Open (*) | |
| Who is QA for v1? | Open (*) | |
| Does the UI need Bahasa Indonesia for parents in v1? | Open (*) | |
| How many children should join the trial? | Open (*) | |
| Should the camera ROM angles be compared with a therapist's goniometer? | Open (*) | |

## Competitive Analysis (Optional)

| Competitor Name | Observation | Notes |
|---|---|---|
| Home exercise program from the therapist (exercise sheet or video) | Predicted: movements are repeated by count, with no feedback and no progress record; children get bored quickly, may be out of date (*) | Motale replaces repetition counts with a drawing activity and records progress automatically (*) |
| Motion-sensing games on home consoles | Predicted: fun and use full-body movement, but need extra hardware and are not designed for the motor abilities of children with CP, may be out of date (*) | Motale needs only the iPad camera, and template levels increase gradually (*) |
| Game-based hand rehabilitation apps | Predicted: many rely on touchscreen input or special devices, so shoulder and wide-range movement get little training, may be out of date (*) | Motale focuses on bilateral and wide-range movement in the air without touching the screen (*) |
| Regular drawing with paper and crayons | Predicted: children like it, but movements are small (hand and wrist) and parents get no data, may be out of date (*) | The wide canvas and pots at the edges push wide arm movements, and the report fills the data gap (*) |

## Product Requirement

**App Overview:**
Motale (app name in code: Puffy Pond) is an iPad drawing game for children aged 10–12 with cerebral palsy (MACS I–II). The child paints in the air with a fist in front of the camera, changes color and brush with a rubbing gesture, then hangs the painting in a 3D museum. While the child plays, the app records arm movement and shows it as a daily report for parents. (*)

**User Story**
- As a child, I want to move my hands in front of the camera to draw on the canvas in real time while changing colors and choosing brushes, so that I can freely experiment and create interactive, colorful art without touching the iPad screen.
- As a child, I want to see my drawings again in a virtual gallery/museum, interact with them through sound that responds to my work, and arrange the position of my frames in the gallery room, so that I can enjoy my own art exhibition in an immersive way.
- As a parent, I want to see my child's movement report, so that I know my child's condition from how they play.

**Feature List vs Importance (MVP)**

| User Flow | User Story | Requirement | Importance |
|---|---|---|---|
| **EPIC 1: Hand Drawing** | **Feature 1.1: Start drawing and choose a mode**<br>As a child, I want to choose Freeform or Template so that I can draw freely or follow a guide. | The system should show Home (Start drawing, View gallery, Report) and a page to choose Freeform or Templates. (*) | P1 - MVP (*) |
| ^ | **Feature 1.2: Pick a template (Daily Quest and progressive unlock)**<br>As a child, I want to choose templates from easy to hard so that the challenge grows step by step. | The system should show the Daily Quest and 9 Easy, Medium, Hard templates, and unlock the next template once a painting of the previous one is saved. (*) | P1 - MVP (*) |
| ^ | **Feature 1.3: Distance check (Get Ready)**<br>As a child, I want to know where to stand so that the camera can read both my hands. | The system should detect a shoulder width of 13–22% of the image width (about 1 m), hold for 1.5 seconds, then open the canvas automatically, with a Skip button. (*) | P1 - MVP (*) |
| ^ | **Feature 1.4: Paint with a fist in real time**<br>As a child, I want to paint by making a fist so that I don't need to touch the screen. | The system should paint on fist, stop on open hand, support both hands at once, and show simulated wet paint. (*) | P1 - MVP (*) |
| ^ | **Feature 1.5: Change color by rubbing a paint pot**<br>As a child, I want to change color with a hand movement so that my painting is colorful. | The system should change the character's color when the ring on a paint pot on the right side fills up from rubbing. (*) | P1 - MVP (*) |
| ^ | **Feature 1.6: Choose a tool by rubbing a tool bubble**<br>As a child, I want to choose different brushes so that I can try different paint textures. | The system should provide 5 tools (Thick oil, Liquid oil, Brush, Eraser, Blender) on the left side and switch to one when its bubble is rubbed until full. (*) | P1 - MVP (*) |
| ^ | **Feature 1.7: Music and sound feedback**<br>As a child, I want to hear music that gets livelier as I move so that I stay excited to keep moving. | The system should play 118 BPM music that gets fuller as movement increases, blip sounds that follow hand height and position, and a music on/off button. (*) | P1 - MVP (*) |
| ^ | **Feature 1.8: Canvas controls and Save image**<br>As a child, I want to save my painting so that I can see it again. | The system should show Save image once there is paint, confirm when leaving without saving, and provide clear, music, camera preview, and help buttons. (*) | P1 - MVP (*) |
| ^ | **Feature 1.9: Review and play with the painting**<br>As a child, I want to pull and stretch my painting so that I can play with my artwork. | The system should show the painting on an elastic sheet that can be pulled (1 fist), stretched and twisted (2 fists), and rippled (open hand), with dwell buttons Save to gallery and Keep drawing. (*) | P2 (*) |
| ^ | **Feature 1.10: Drawing without a camera**<br>As a child, I want to still draw by touch so that I can play when the camera is not available. | The system should support every step by touch or mouse, and show a message when camera access is denied. (*) | P2 (*) |
| **EPIC 2: Virtual Museum / Gallery** | **Feature 2.1: Walk the 3D gallery with a paddle gesture**<br>As a child, I want to walk through the museum by swinging my hand so that viewing my work feels like an exhibition. | The system should hang paintings in a 3D museum and move between paintings when an open hand sweeps down ≥ 25% of the screen height within 0.8 seconds (right = next, left = back). (*) | P1 - MVP (*) |
| ^ | **Feature 2.2: 2D gallery**<br>As a child, I want to see all my paintings in a grid so that I can find one painting quickly. | The system should show a thumbnail grid by day and open the chosen painting in the 3D gallery. (*) | P2 (*) |
| ^ | **Feature 2.3: Take a painting down**<br>As a child, I want to delete paintings I don't like so that the gallery holds my favorites. | The system should delete the PNG and sidecar after the "Take this painting down?" confirmation. (*) | P2 (*) |
| ^ | **Feature 2.4: Audio that responds to the artwork**<br>As a child, I want to hear sound made from my painting so that my exhibition feels alive. | The system should play sound made from a painting's colors or tools when the child stands in front of it. (*) | P3 (*) |
| ^ | **Feature 2.5: Arrange the frame layout**<br>As a child, I want to move frames around the room so that I can arrange my own exhibition. | The system should provide an arrange mode to move frames with a fist and save their positions. (*) | P3 (*) |
| **EPIC 3: Movement Report** | **Feature 3.1: Open the Report and pick a day**<br>As a parent, I want to pick a date on a calendar so that I can see the report for that day. | The system should show a month calendar with a dot on days with paintings and a star for the Daily Quest. (*) | P1 - MVP (*) |
| ^ | **Feature 3.2: See the day's paintings**<br>As a parent, I want to see my child's paintings from that day so that I know what they worked on. | The system should show a strip of the selected day's paintings with template name and time. (*) | P2 (*) |
| ^ | **Feature 3.3: ROM stats**<br>As a parent, I want to see how high my child raises their arms so that I know how their movement develops. | The system should show Highest ROM for the left and right shoulder, straightest elbow, hand above shoulder, reach area, grip cycles, and a lean flag. (*) | P1 - MVP (*) |
| ^ | **Feature 3.4: Heatmap and hand dominance**<br>As a parent, I want to see which areas were painted and which hand was used more so that I know whether both hands are being trained. | The system should show a 32 × 20 heatmap and each hand's share of painting time. (*) | P1 - MVP (*) |
| ^ | **Feature 3.5: Movement data recording**<br>As a parent, I want my child's data stored safely on the device so that their privacy is kept. | The system should record stats only on the Canvas page from the camera, and save them as a JSON sidecar on the device with no network. (*) | P1 - MVP (*) |

## Acceptance Criteria

| User Flow | User Story | Screen | Acceptance Criteria | Positive Flow |
|---|---|---|---|---|
| **EPIC 1: Hand Drawing** | **Feature 1.1: Start drawing and choose a mode** | Home, Mode Picker | • Home shows Start drawing, View gallery, and Report buttons.<br>• Start drawing opens "What do you want to paint?" with Freeform and Choose template.<br>• Freeform opens Get Ready with a blank canvas.<br>• The mode page has a Home button. (*) | POSITIVE:<br>1. Child taps Start drawing.<br>2. Child picks Freeform.<br>3. Get Ready page opens. (*) |
| ^ | ^ | Mode Picker | ^ | NEGATIVE FLOW:<br>1. Child taps Home on the mode page.<br>2. App returns to Home without opening the canvas. (*) |
| ^ | **Feature 1.2: Pick a template (Daily Quest and progressive unlock)** | Templates | • Daily Quest sits on top, rolled once per day, never the same as yesterday.<br>• 9 templates: Easy (fish, duck, sun), Medium (turtle, snail, cat), Hard (octopus, seahorse, butterfly).<br>• A template unlocks once a painting of the previous template is saved.<br>• A locked template shows "Save a painting of <previous template> to unlock".<br>• Deleting a painting can lock a template again.<br>• Back and Home buttons are present. (*) | POSITIVE:<br>1. Child opens Templates.<br>2. Child taps an unlocked template (Fish).<br>3. Get Ready opens with the Fish template. (*) |
| ^ | ^ | Templates | ^ | NEGATIVE FLOW:<br>1. Child taps a locked template (Turtle).<br>2. Template does not open and the unlock hint stays visible. (*) |
| ^ | **Feature 1.3: Distance check (Get Ready)** | Get Ready | • Shows a skeleton outline and the arms the camera sees.<br>• In range when shoulder width is 13–22% of the image width and the body is centered (±18%).<br>• Hold still 1.5 seconds until the ring fills, then the canvas opens automatically.<br>• A lost detection < 0.3 seconds does not reset the hold.<br>• Skip is always available. (*) | POSITIVE:<br>1. Child steps back until shoulders fit the outline.<br>2. Ring fills over 1.5 seconds.<br>3. Canvas opens automatically. (*) |
| ^ | ^ | Get Ready | ^ | NEGATIVE FLOW:<br>1. Child stands too close (shoulders > 22% of image width).<br>2. Ring does not fill and the child is asked to step back; the child can tap Skip. (*) |
| ^ | **Feature 1.4: Paint with a fist in real time** | Canvas | • Each hand has a paint character that follows it in real time.<br>• Open hand: character moves without paint.<br>• Fist: character paints; a loosening fist keeps painting briefly.<br>• Both hands can paint at once, each with its own color and tool.<br>• A wide canvas and pots at the edges push wide arm movements.<br>• The template shows as a dotted guide. (*) | POSITIVE:<br>1. Child moves an open hand; the character follows.<br>2. Child makes a fist and sweeps the arm; paint appears.<br>3. Child opens the hand; painting stops. (*) |
| ^ | ^ | Canvas | ^ | NEGATIVE FLOW:<br>1. Child's hand leaves the camera view while painting.<br>2. The stroke and character stop; painting resumes when the hand is seen again. (*) |
| ^ | **Feature 1.5: Change color by rubbing a paint pot** | Canvas | • Paint pots stand in a column on the right of the canvas.<br>• Rubbing back and forth fills a ring; faster rubbing fills it faster.<br>• A full ring changes the color, with a sound and an animation in the HUD.<br>• Colors are bright and high-contrast.<br>• HUD chips show each hand's color and tool. (*) | POSITIVE:<br>1. Child moves the character to a pot.<br>2. Child rubs until the ring is full.<br>3. Character paints with the new color. (*) |
| ^ | ^ | Canvas | ^ | NEGATIVE FLOW:<br>1. Child stops rubbing before the ring is full.<br>2. Color does not change and the ring empties again. (*) |
| ^ | **Feature 1.6: Choose a tool by rubbing a tool bubble** | Canvas | • Tool bubbles stand in a column on the left with 5 characters.<br>• Thick oil (Snail), Liquid oil (Jellyfish), Brush (Octopus), Eraser (Starfish), Blender (Sponge).<br>• A full ring switches the tool with a swap sound.<br>• Left and right hands can use different tools. (*) | POSITIVE:<br>1. Child moves the character to the Jellyfish bubble.<br>2. Child rubs until full.<br>3. The next stroke uses Liquid oil. (*) |
| ^ | ^ | Canvas | ^ | NEGATIVE FLOW:<br>1. Child rubs the bubble of the tool already in use.<br>2. Tool does not change and there is no swap sound. (*) |
| ^ | **Feature 1.7: Music and sound feedback** | Canvas | • 118 BPM toy-pop music plays on the canvas.<br>• Music layers get fuller as movement increases.<br>• Blip sound: pitch follows hand height, left/right pan follows hand position.<br>• Every action has a sound effect (color change, tool change, finish).<br>• Characters bob to the beat.<br>• A speaker button turns music on and off. (*) | POSITIVE:<br>1. Canvas opens and the music starts.<br>2. Child sweeps the arms; the music gets fuller and blips play.<br>3. Child changes color; a sound effect plays. (*) |
| ^ | ^ | Canvas | ^ | NEGATIVE FLOW:<br>1. Parent taps the speaker button.<br>2. Music stops, the icon changes to a crossed-out speaker, and painting keeps working. (*) |
| ^ | **Feature 1.8: Canvas controls and Save image** | Canvas | • Buttons: Home, touch eraser (iPad), music, camera preview, help, clear.<br>• Save image appears only once there is paint.<br>• Save image captures the canvas without characters, pots, or template guide, then opens Review.<br>• Home before saving shows "Leave without saving?".<br>• Clear removes paint, strokes, and the template guide. (*) | POSITIVE:<br>1. Child finishes painting.<br>2. Save image button appears.<br>3. Child taps Save image; Review opens. (*) |
| ^ | ^ | Canvas | ^ | NEGATIVE FLOW:<br>1. Child taps Home before saving.<br>2. "Leave without saving?" appears; Keep drawing returns to the canvas with the paint intact. (*) |
| ^ | **Feature 1.9: Review and play with the painting** | Review | • The painting shows on an elastic sheet.<br>• 1 fist pulls, 2 fists stretch and twist (0.3×–3.5×), an open hand makes ripples with a splash sound.<br>• The sheet springs back when released; the saved image does not change.<br>• Keep drawing and Save to gallery can be tapped or chosen by dwelling an open hand; only the first trigger counts. (*) | POSITIVE:<br>1. Child stretches the sheet with 2 fists.<br>2. Child holds an open hand on Save to gallery.<br>3. Painting is saved and the 3D gallery opens with a cheer. (*) |
| ^ | ^ | Review | ^ | NEGATIVE FLOW:<br>1. Child picks Keep drawing.<br>2. App returns to the same canvas with the paint still there; no new painting in the gallery. (*) |
| ^ | **Feature 1.10: Drawing without a camera** | All pages | • Every step works by touch or mouse.<br>• Drag to paint; drag through a pot or bubble to change color or tool.<br>• Erase: eraser button on iPad, ⌥-drag or right-drag on Mac.<br>• Touch paintings have no movement data. (*) | POSITIVE:<br>1. Child taps Skip on Get Ready.<br>2. Child drags a finger to paint.<br>3. Child saves; the painting appears in the gallery. (*) |
| ^ | ^ | Canvas | ^ | NEGATIVE FLOW:<br>1. Camera access is denied.<br>2. "Camera access is off" appears with an Open Settings button; the child can still paint by touch. (*) |
| **EPIC 2: Virtual Museum / Gallery** | **Feature 2.1: Walk the 3D gallery with a paddle gesture** | 3D Gallery | • Gallery opens from View gallery or after Save to gallery.<br>• Paintings hang in frames, newest first; animal characters visit.<br>• An open hand sweeping down ≥ 25% of screen height within 0.8 seconds: right = next, left = back; 0.6-second cooldown.<br>• Arrow buttons and swipes also work.<br>• Header shows the date and "n of N".<br>• A new painting is greeted with a cheer and confetti. (*) | POSITIVE:<br>1. Child opens the gallery.<br>2. Child sweeps an open hand down on the right side.<br>3. Camera walks to the next painting. (*) |
| ^ | ^ | 3D Gallery | ^ | NEGATIVE FLOW:<br>1. The gallery has no paintings yet.<br>2. "No paintings yet" appears with a Start drawing button. (*) |
| ^ | **Feature 2.2: 2D gallery** | 2D Gallery | • View gallery in 2D opens a thumbnail grid by day, newest first.<br>• Tapping a thumbnail opens that painting in the 3D gallery.<br>• The 3D button returns to the museum. (*) | POSITIVE:<br>1. Child taps View gallery in 2D.<br>2. Child taps a painting.<br>3. The 3D gallery opens at that painting. (*) |
| ^ | ^ | 2D Gallery | ^ | NEGATIVE FLOW:<br>1. The 2D gallery is opened with no paintings.<br>2. "No paintings yet" appears with Start drawing. (*) |
| ^ | **Feature 2.3: Take a painting down** | 3D Gallery | • The trash button shows "Take this painting down?".<br>• Confirming deletes the PNG and sidecar, then the gallery re-hangs the paintings.<br>• Deleting can lock a template again and changes the Report. (*) | POSITIVE:<br>1. Child taps trash.<br>2. Child picks Take it down.<br>3. The painting disappears from the gallery. (*) |
| ^ | ^ | 3D Gallery | ^ | NEGATIVE FLOW:<br>1. Child taps trash, then closes the dialog.<br>2. The painting stays. (*) |
| ^ | **Feature 2.4: Audio that responds to the artwork** | 3D Gallery | • When the child stands in front of a painting, sound is made from that painting's colors or tools.<br>• A hand movement toward the painting triggers an audio response.<br>• Not in the code yet (P3). (*) | POSITIVE:<br>1. Child walks to a painting.<br>2. The painting's music plays.<br>3. Child pushes an open hand; the sound reacts. (*) |
| ^ | ^ | 3D Gallery | ^ | NEGATIVE FLOW:<br>1. Music is turned off in settings.<br>2. The gallery does not play painting sounds. (*) |
| ^ | **Feature 2.5: Arrange the frame layout** | 3D Gallery (arrange mode) | • The child enters arrange mode, grabs a frame with a fist, and moves it.<br>• The position is saved and stays the same when the gallery is reopened.<br>• Not in the code yet (P3). (*) | POSITIVE:<br>1. Child enters arrange mode.<br>2. Child moves a frame with a fist.<br>3. The layout stays after reopening the gallery. (*) |
| ^ | ^ | 3D Gallery (arrange mode) | ^ | NEGATIVE FLOW:<br>1. Child releases a frame on a spot that is already taken.<br>2. The frame returns to its original spot. (*) |
| **EPIC 3: Movement Report** | **Feature 3.1: Open the Report and pick a day** | Home, Report | • Report opens from the Report button on Home.<br>• Month calendar: a dot for days with paintings, a star for the Daily Quest.<br>• Tapping a day shows its detail on the right.<br>• Arrow buttons change the month. (*) | POSITIVE:<br>1. Parent taps Report.<br>2. Parent taps a marked day.<br>3. That day's paintings and stats appear. (*) |
| ^ | ^ | Report | ^ | NEGATIVE FLOW:<br>1. Parent taps a day with no paintings.<br>2. "No drawing this day" appears. (*) |
| ^ | **Feature 3.2: See the day's paintings** | Report | • A strip of the day's paintings, newest first.<br>• Each item: thumbnail, template name or freeform, and time.<br>• Thumbnails load in the background. (*) | POSITIVE:<br>1. Parent selects a day.<br>2. The strip shows paintings with template and time. (*) |
| ^ | ^ | Report | ^ | NEGATIVE FLOW:<br>1. That day's painting was deleted from the gallery.<br>2. The painting no longer shows in the strip. (*) |
| ^ | **Feature 3.3: ROM stats** | Report | • Highest ROM shoulder abduction, left and right, in degrees.<br>• Straightest elbow, hand above shoulder, reach area, grip cycles per arm.<br>• Lean flag when the shoulders tilt > 15°.<br>• Daily values are the maximum (ROM) or sum (time, grip) of all sessions.<br>• Left/right are the child's own sides.<br>• The note "Camera estimates, not a clinical measurement." is always shown. (*) | POSITIVE:<br>1. Parent selects a day the child painted with the camera.<br>2. The Highest ROM card shows left and right angles.<br>3. Parent reads the other stats. (*) |
| ^ | ^ | Report | ^ | NEGATIVE FLOW:<br>1. Parent selects a day whose paintings were made by touch.<br>2. "No movement data — these were drawn by touch or before tracking existed." appears. (*) |
| ^ | **Feature 3.4: Heatmap and hand dominance** | Report | • Heatmap 32 × 20 grid: transparent where empty, yellow to red the longer it was painted.<br>• Hand dominance: Left % and Right %, totaling 100%. (*) | POSITIVE:<br>1. Parent selects a day.<br>2. The heatmap and hand dominance bar appear. (*) |
| ^ | ^ | Report | ^ | NEGATIVE FLOW:<br>1. There was no fist painting time that day.<br>2. "No painting time recorded" appears. (*) |
| ^ | **Feature 3.5: Movement data recording** | Canvas, storage | • Stats are recorded only on Canvas, from hands and body the camera sees.<br>• A joint is used if confidence ≥ 0.5; values come from a 0.3-second median.<br>• Saved as a JSON sidecar in Application Support/Gallery/.<br>• No network and no accounts. (*) | POSITIVE:<br>1. Child paints with the camera and saves.<br>2. PNG and JSON sidecar are saved.<br>3. Report shows today's numbers. (*) |
| ^ | ^ | Canvas | ^ | NEGATIVE FLOW:<br>1. The camera loses the child's body for one frame.<br>2. That frame does not create a fake ROM record because values come from a median. (*) |

## Event Tracker (Optional)

Note: v1 has no network, so events are written to a local log on the device and collected during the trial. This event logging is not in the code yet. (*)

| User Flow | User Story | Event Tracker |
|---|---|---|
| **EPIC 1: Hand Drawing** | **Feature 1.1: Start drawing and choose a mode** | DR_Home_Page<br>DR_StartDrawing_Button<br>DR_Freeform_Button<br>DR_ChooseTemplate_Button (*) |
| ^ | **Feature 1.2: Pick a template** | DR_Templates_Page<br>DR_Template_Select (properties: template, level)<br>DR_DailyQuest_Select<br>DR_Template_Unlock (property: template) (*) |
| ^ | **Feature 1.3: Distance check** | DR_GetReady_Page<br>DR_GetReady_Complete (property: duration)<br>DR_GetReady_Skip (*) |
| ^ | **Feature 1.4–1.7: Painting, color, tool, music** | DR_Canvas_Page (property: session duration)<br>DR_Stroke_Start (property: hand)<br>DR_Color_Change<br>DR_Tool_Change (property: tool)<br>DR_Music_Toggle (*) |
| ^ | **Feature 1.8–1.9: Save image and Review** | DR_SaveImage_Button<br>DR_Review_Page<br>DR_SaveToGallery_Button<br>DR_KeepDrawing_Button<br>DR_LeaveWithoutSaving_Confirm (*) |
| **EPIC 2: Virtual Museum / Gallery** | **Feature 2.1–2.3: 3D gallery, 2D gallery, delete** | GL_Gallery3D_Page<br>GL_Paddle_Gesture (property: direction)<br>GL_Gallery2D_Page<br>GL_Painting_Remove (*) |
| **EPIC 3: Movement Report** | **Feature 3.1–3.4: Report** | RP_Report_Page<br>RP_Day_Select (properties: date, has movement data) (*) |

Metrics that can't be counted from events: play motivation, report understanding, report taken to therapist, and clinically useful report. All four come from observation and interviews during the trial. (*)

## Test Case

| User Flow | Scenario | Test Steps | Expected Result |
|---|---|---|---|
| **EPIC 1: Hand Drawing** | **Scenario 1.1.1**: Start Freeform | 1. Open the app on iPad.<br>2. Tap Start drawing.<br>3. Tap Freeform. | - Get Ready opens with a blank canvas. (*) |
| ^ | **Scenario 1.1.2**: Back to Home from the mode page | 1. Tap Start drawing.<br>2. Tap Home. | - Home shows again. (*) |
| ^ | **Scenario 1.2.1**: Pick an unlocked template | 1. Start with an empty gallery.<br>2. Open Templates.<br>3. Tap Fish. | - Get Ready opens; the Fish dotted guide shows on the canvas. (*) |
| ^ | **Scenario 1.2.2**: Locked template | 1. Start with no Sun painting in the gallery.<br>2. Open Templates.<br>3. Tap Turtle. | - Turtle does not open; "Save a painting of Sun to unlock" shows. (*) |
| ^ | **Scenario 1.2.3**: Unlock, then lock again | 1. Save a painting from the Sun template.<br>2. Check that Turtle is unlocked.<br>3. Delete the Sun painting in the gallery.<br>4. Open Templates again. | - Turtle is locked again. (*) |
| ^ | **Scenario 1.3.1**: Correct distance | 1. Pick Freeform.<br>2. Stand about 1 m away, centered in the camera.<br>3. Hold still 1.5 seconds. | - Ring fills and the canvas opens automatically. (*) |
| ^ | **Scenario 1.3.2**: Too close | 1. Pick Freeform.<br>2. Stand about 40 cm from the camera. | - Ring does not fill; Skip still works. (*) |
| ^ | **Scenario 1.4.1**: Paint with a fist | 1. Open the canvas.<br>2. Move an open hand.<br>3. Make a fist and sweep the arm.<br>4. Open the hand. | - Character follows without paint on open hand; paint appears on fist; stops when the hand opens. (*) |
| ^ | **Scenario 1.4.2**: Both hands at once | 1. Open the canvas.<br>2. Make fists with both hands and sweep together. | - Two strokes appear at once, each in its hand's color. (*) |
| ^ | **Scenario 1.4.3**: Hand leaves the camera | 1. Paint with a fist.<br>2. Move the hand out of the camera view. | - The stroke stops; it resumes when the hand is seen again. (*) |
| ^ | **Scenario 1.5.1**: Change color | 1. Move the character to a pot on the right.<br>2. Rub until the ring is full. | - The character's color and HUD chip change; a sound plays. (*) |
| ^ | **Scenario 1.5.2**: Rub stops before full | 1. Rub a pot briefly.<br>2. Stop before the ring is full. | - Color stays; ring empties again. (*) |
| ^ | **Scenario 1.6.1**: Change tool | 1. Move the character to the Jellyfish bubble.<br>2. Rub until full.<br>3. Paint with a fist. | - The stroke is translucent, running Liquid oil. (*) |
| ^ | **Scenario 1.6.2**: Rub the same tool | 1. Use Brush (Octopus).<br>2. Rub the Octopus bubble. | - Tool does not change; no swap sound. (*) |
| ^ | **Scenario 1.7.1**: Music responds to movement | 1. Open the canvas.<br>2. Stay still 5 seconds.<br>3. Sweep both arms for 10 seconds. | - Music gets fuller while moving; blips follow the hands. (*) |
| ^ | **Scenario 1.7.2**: Turn music off | 1. Open the canvas.<br>2. Tap the speaker button. | - Music stops; crossed-out speaker icon; painting still works. (*) |
| ^ | **Scenario 1.8.1**: Save image | 1. Paint one stroke.<br>2. Tap Save image. | - Review opens; the image has no characters, pots, or template guide. (*) |
| ^ | **Scenario 1.8.2**: Leave without saving | 1. Paint one stroke.<br>2. Tap Home.<br>3. Pick Keep drawing. | - "Leave without saving?" appears; back to the canvas with paint intact. (*) |
| ^ | **Scenario 1.9.1**: Save to gallery by dwell | 1. On Review, hold an open hand on Save to gallery until the ring fills. | - Painting is saved; the 3D gallery opens at it with a cheer. (*) |
| ^ | **Scenario 1.9.2**: Keep drawing | 1. On Review, tap Keep drawing. | - The same canvas opens; the gallery count does not increase. (*) |
| ^ | **Scenario 1.10.1**: Paint by touch | 1. Tap Skip on Get Ready.<br>2. Drag a finger on the canvas.<br>3. Save image, then Save to gallery. | - Painting is saved; that day's Report shows "No movement data". (*) |
| ^ | **Scenario 1.10.2**: Camera access denied | 1. Deny camera permission in Settings.<br>2. Open the canvas. | - "Camera access is off" with Open Settings; finger drag still paints. (*) |
| **EPIC 2: Virtual Museum / Gallery** | **Scenario 2.1.1**: Paddle forward and back | 1. Prepare 3 paintings.<br>2. Open the gallery.<br>3. Sweep an open hand down on the right.<br>4. Sweep on the left. | - Moves to the next painting, then back; the "n of 3" header changes. (*) |
| ^ | **Scenario 2.1.2**: Empty gallery | 1. Delete all paintings.<br>2. Open View gallery. | - "No paintings yet" with Start drawing. (*) |
| ^ | **Scenario 2.2.1**: Open from 2D | 1. Open the 3D gallery.<br>2. Tap View gallery in 2D.<br>3. Tap the second painting. | - The 3D gallery opens at the second painting. (*) |
| ^ | **Scenario 2.2.2**: Empty 2D gallery | 1. Delete all paintings.<br>2. Open the 2D gallery. | - "No paintings yet" shows. (*) |
| ^ | **Scenario 2.3.1**: Delete a painting | 1. Open the gallery.<br>2. Tap trash.<br>3. Pick Take it down. | - The painting disappears; PNG and sidecar files are deleted. (*) |
| ^ | **Scenario 2.3.2**: Cancel delete | 1. Tap trash.<br>2. Close the dialog. | - The painting stays. (*) |
| ^ | **Scenario 2.4.1**: Painting audio (P3) | 1. Open the gallery.<br>2. Stand in front of a painting. | - Sound from the painting plays. (*) |
| ^ | **Scenario 2.5.1**: Move a frame (P3) | 1. Enter arrange mode.<br>2. Move a frame with a fist.<br>3. Close and reopen the gallery. | - The frame stays in its new spot. (*) |
| **EPIC 3: Movement Report** | **Scenario 3.1.1**: Pick a marked day | 1. Save a painting today.<br>2. Open Report.<br>3. Tap today. | - A dot shows on the date; the day detail appears on the right. (*) |
| ^ | **Scenario 3.1.2**: Day with no paintings | 1. Open Report.<br>2. Tap a date with no paintings. | - "No drawing this day" shows. (*) |
| ^ | **Scenario 3.1.3**: Daily Quest star | 1. Save a Daily Quest painting.<br>2. Open Report. | - Today's date has a star. (*) |
| ^ | **Scenario 3.2.1**: Painting strip | 1. Save 2 paintings today.<br>2. Open today's Report. | - 2 thumbnails show with template name and time. (*) |
| ^ | **Scenario 3.3.1**: ROM stats show | 1. Paint with the camera while raising the arms to the side.<br>2. Save.<br>3. Open today's Report. | - Left and right Highest ROM show in degrees; the "Camera estimates" note shows. (*) |
| ^ | **Scenario 3.3.2**: No movement data | 1. Paint by touch only.<br>2. Save.<br>3. Open today's Report. | - "No movement data" shows. (*) |
| ^ | **Scenario 3.4.1**: Heatmap and hand dominance | 1. Paint on the left side of the canvas, using the left hand longer.<br>2. Save.<br>3. Open Report. | - Heatmap is red on the left; Left % is greater than Right %. (*) |
| ^ | **Scenario 3.4.2**: No painting time | 1. Open the canvas, move only with an open hand, then save a touch painting.<br>2. Open Report. | - "No painting time recorded" or "No movement data" shows. (*) |
| ^ | **Scenario 3.5.1**: Data stored locally | 1. Turn on airplane mode.<br>2. Paint and save.<br>3. Check the Application Support/Gallery/ folder. | - PNG and JSON sidecar exist; the app works without a network. (*) |
