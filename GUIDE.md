# PREP — Poori App Guide (ISI/CMI Exam Prep Tracker)

Ek app jisme tera **poora exam prep loop** manage hota hai: syllabus → tasks → mocks →
revision → stats. Sab data **phone me locally** save hota hai (koi account nahi, koi
internet nahi chahiye).

---

## 1. Quick Start (2 minute setup)

1. App kholo → intro screen "PREP · prepare · focus · succeed" dikhega.
2. **Dashboard** pe sabse upar **"Set exam date"** dabao → apna exam naam likho
   (jaise `ISI B.Math 2027`) → date pick karo → **"Start countdown"**.
3. **Syllabus** pe jao (left side 🗂️ icon) → chapters ko tap karke mark karte jao.
4. **Planner** pe us din ki tasks daalo (alarm ke saath bhi).
5. Roz bas 2 kaam: **tasks complete karo** (streak banegi) aur **kaam khatam
   hone pe chapter DONE karo** (revision reminders auto banenge).

---

## 2. Dashboard (Home — Center Column)

Sabse zyada information ek jagah. Up se neeche:

| Card | Kya dikhata hai |
|---|---|
| **Greeting** | Good morning/afternoon + aaj ki date |
| **Exam countdown (HERO)** | Sabse bada card. Exam naam + `42d 06:12:33` live tick + date. ✏️ = edit, ✕ = hatao. Date nikal jaye → "Exam day! 🎉" |
| **High Contrast Info** | Headline coverage % + numbers: exams, units/chapters, done/doing/partial, backlog, test attempts, scheduled revisions |
| **Focus Timer** | **25 / 45 / 60 min** presets ya custom HH:MM:SS. Start/Pause/Reset, **Focus** (DND lock), completion sound selectable. Full-screen bhi hota hai |
| **Live & Upcoming** | Abhi kya chal raha hai: LIVE schedule slots, next slot, task alarm countdown, next reminder ("event in"), aaj ka mock test (`TODAY · 09:00` + countdown), next mock day |
| **Streak 🔥** | Kitne din lagaatar goal pura kiya. **Goal select yahin se karo** (`[−] 3 [+] tasks/day`). Progress bar + "Today: 2/3 tasks" |
| **Weekly stats** | Last 7 din ke completed tasks ka bar chart + "+20% vs last week" |
| **Daily history** | Har din ka breakdown: `✓ Mon 10 Aug 3/3 tasks` (green ✓ = goal pura) |
| **Mock test trend** | Last 6 mock attempts ke % bars + avg (sirf jab result log karo) |
| **Backlog** | Overdue tasks, "overdue by 2d 04:12:08" tick hota rehta hai |
| **Exam Progress** | Har exam ka countdown + per-exam coverage |

---

## 3. Syllabus (Exam Tree)

Multi-exam tree: **Exam → Unit → Chapter → Topic**. Root me default `ISI · CMI`.

- **Status cycle** — chapter pe status chip tap karo: `NOT DONE → DOING → PARTIAL → DONE`
  (aur wapas). Tap karte hi status badal jata hai.
- **DONE karne pe magic**: leaf item (chapter) DONE hote hi **3 auto reminders bante
  hain** → notebook abhi wapis bhi dekh sakte ho: `Revision: <name>` at **+3, +7, +14 din,
  shaam 6 baje** (Dashboard "event in" me + notification bhi). Un-done karo → cancel.
- **Node details** (har item tap karke): naam rename, **Add item** (child), **Delete**,
  status stepper, **Total test attempts** (+/−), **Revisions count** (+/−),
  **Next revision** (date pick kar sakte ho).
- **Add Exam** button — naya exam tree (jaise "CMI 2027").
- Header pills: total chapters, `X test attempts`, done/doing/partial NOT DONE counts.

> Tip: Parent pe status lagao to wo aggregate dikhata hai (bina kisi extra kaam ke).

---

## 4. Planner (Daily Tasks)

- **Add row** — title likho, phir:
  - **Bucket pill** — `Today` / `Upcoming` / `Backlog` me daalo
  - **Reminder toggle** ON karo → **hour/minute** chuno → **sound** chuno
    (`No sound / Beep / Chime / Ding / Pulse / Synth` ya apna custom file) →
    **ring duration** (`10s, 30s, 1min, 2min, 5min`)
- **Alarm kaam kaise karta hai**: time aate hi app ke andar full-screen ring + sound;
  app band ho to bhi **Android system notification + alarm sound**. Options:
  **Start the task** (done), **Reschedule**, **Stop**.
- Ek task ko: `↻` **rename** karke, `✕` **double-tap** delete.
- Buckets: **Today** / **Upcoming** (future tasks) / **Backlog** (overdue — har task
  "elapsed" timer ke saath).
- Alarm time guzar jaye to task ki alarm apne aap clear ho jati hai (dubara ring nahi).

---

## 5. Calendar (Month Grid)

- **Day select** karo → us din ki tasks neeche dikhti hain.
- **"Mark X as a Mock test day"** — tap = mock day (calendar pe "M" badge).
  Mock day pe:
  - **⏰ alarm chip** — time chuno → aaj wo time pe "Mock test" reminder bajega
  - **scoreboard chip (green)** — **marks/max** daalo (jaise `42/60`) → Dashboard
    "Mock test trend" me bar banega
- **"Mark X as …" (custom markers)** — mock jaisa hi concept, apne naam se:
  - **Options** button → **"New option"** → naam + color chuno (8 colors)
  - Har option ek toggle row: `Mark 10 Aug as Revision` — tap = mark/unmark
  - Marked day = us color ka highlight + pehla letter badge
  - 🔔 alarm bhi lagao marker pe ("Marked 10 Aug as Revision · 18:00")
- **Custom date add**: add row me 📅 tap karke agla din — task seedha future day pe
  jata hai.
- Calendar pe per-day **pending badge** (kitne tasks baaki).

---

## 6. Schedule (Weekly Study Slots)

- Fixed weekly slots: **din (Mon–Sun) + start time + end time** (ClockInput se,
  midnight-crossing bhi allowed).
- Add / rename / delete (double-tap ✕).
- **Conflict handling**: naya slot pehle se busy time pe daalo → purana slot
  **auto-push** ho jata hai aage (offset choose karke).
- Dashboard "Live & Upcoming" inhi slots ko dikhata hai (LIVE abhi + next slot).

---

## 7. Profile (Top-Right 👤)

| Section | Kya hai |
|---|---|
| Developer message | + "Email feedback" button (zen201247007@gmail.com) |
| **About** | Version info |
| **Theme picker** | Alag-alag palettes — ek tap me poori app restyle |
| **Alarm sound** | 🔔 pick karo: built-in sounds ya **apni audio file** (phone se select; Android notification bhi wahi sound use karega; web pe file store ho jati hai) |
| **Progress & goals** | **Daily goal** (+/−), **Daily plan notification** toggle |
| **Backup & Restore** | **Export data** → ek `.prep` file (sab progress + settings). **Import data** → wapas lao. Naya phone / wapas reset ke baad + backup = safe |
| **Reset all data** | Sab kuch clear — syllabus seed wapas, sab kuch empty. Double confirm ke baad |

**Daily plan notification**: ON karo → har roz **9:00 PM** notification:
`Prep — Kal ka plan: Kal: 3 tasks · 1 mock test`. Body har app-kholne pe fresh
compute hoti hai. (Android pe system notification; web pe sirf app me.)

---

## 8. Notifications & Alarms — Platform Difference

| | Android 📱 | Web 🌐 |
|---|---|---|
| Reminders / alarms | System notification + full-screen + sound — **app band ho tab bhi** | App kholi ho tab in-app popup; sound bajta hai |
| Custom sound file | File copy hoti hai phone me; notification sound usi file se | File base64 me save hoti hai (6MB limit) |
| Daily plan (9 PM) | System notification | No-op (toggle persists) |
| Permissions | Pehli bar alarm set karte waqt: exact alarms + full-screen intent + notifications — **Allow karo** | Koi permission nahi |

App ke andar reminder aane pe **popup** dikhta hai: **Close / Snooze** (wahi popup
sab platforms pe).

---

## 9. Data & Reset

- Sab kuch **SharedPreferences** me save — app band karne pe kuch nahi udta.
- Naya phone: **Profile → Export** (file bhejo) → naye pe **Import**.
- Reset All = planner tasks, schedule, mock marks, exam countdowns, pinned exam,
  markers, streak history — sab clear; syllabus fresh seed. **Pehle export kar lena!**

---

## 10. Chrome / Phone kholne ka tarika (Dev)

- **Web**: `flutter run -d chrome` ya release build:
  `python -m http.server 8000 --directory build\web` → `http://localhost:8000`
- **Android APK**: `flutter build apk --release` →
  `build\app\outputs\flutter-apk\app-release.apk` (phone me copy → install,
  "unknown sources" allow karo — debug key se signed hai).

---

## 11. Ek Healthy Daily Routine (suggested)

1. **Subah**: Dashboard dekho — exam countdown + kal ka plan.
2. **Din me**: Focus Timer (25 min) se study; tasks complete karte jao.
3. **Khatam hone pe**: Syllabus me wo chapter **DONE** — revision todo-set bani.
4. **Mock test day**: Calendar pe mock mark; time se pehle alarm; baad me score log.
5. **Raat 9 baje**: Daily plan notification bata dega kal kya karna hai.