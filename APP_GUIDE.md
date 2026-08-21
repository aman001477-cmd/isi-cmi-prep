# ISI CMI Prep — Poora User Guide

Ye guide aapko app ka **har feature** step-by-step samjhaata hai, bilkul aasaan
bhaasha mein. App kya hai se lekar daily use tak — sab kuch yahan hai.

---

## 1. App kya hai?

**ISI CMI Prep** ek self-study companion app hai jo aapko help karta hai:

- **Syllabus cover karna** — exam-wise breakdown aur completion tracking
- **Roz ka plan banana** — To-Do list, calendar, reminders
- **Mock tests track karna** — test days mark karna, marks log karna, trends dekhna
- **Consistency banaye rakhna** — streaks (lagaatar din), weekly stats
- **Time manage karna** — focus timer, schedule (roz ka routine), countdowns

**Sab data aapke device par hi rehta hai** — koi internet/account nahi chahiye,
koi server nahi. App offline chalta hai. Phone/tablet par APK se, computer par
browser se.

---

## 2. App kaise chalayein?

### Option A — Computer (browser)
1. `flutter run -d chrome` chalao (ya `flutter build web --release` karke
   `build\web` folder ko kisi bhi static server par daalo).
2. Local server pehle se chal raha hai to: `http://localhost:8000` kholo.
3. Kuch bhi change ho to page hard refresh karo (**Ctrl+Shift+R**).

### Option B — Android phone (APK)
1. `app-release.apk` file phone par bhejo (cable ya WhatsApp/Drive se).
2. Phone par file kholo → "Install" dabao.
3. Agar *Play Protect* ka popup aaye to **"Install anyway"** (ye Google Play se
   bahar ki file hai — normal baat hai).
4. Alarms/reminders phone par **poore kaam karte hain** — web browser par in
   ki limitation hai, isliye daily use ke liye APK best hai.

---

## 3. Screen ka layout

- **Top bar** — left me app logo, right me: 🌙/☀️ dark-mode toggle, avatar chip
  (profile sheet kholta hai).
- **Left rail / bottom nav** — 6 sections: **Dashboard, Syllabus, To Do List,
  Calendar, Stats, Schedule**.
- **Right rail (bade screen par)** — Quick Memo, Deep Focus timer, "Open To Do
  List" button.

---

## 4. Dashboard — sab kuch ek nazar mein

Ye aapka home page hai. Cards ek-ek karke:

| Card | Kya dikhata hai |
|---|---|
| **Greeting** | Time ke hisaab se "Good morning/evening", aaj ki date |
| **Exam countdown (hero)** | Sabse paas wale exam tak kitne din bache (exam date Syllabus me set hoti hai) |
| **High Contrast stats** | Syllabus ka completion %, topics done/scheduled, total topics |
| **Focus Timer** | Pomodoro-style timer — **25 / 45 / 60 min** preset, custom hours+minutes, Start/Pause/Reset + **Focus** toggle (DND). Neeche **"Today: 2h 15m studied"** dikhta hai. **Overlay** button se countdown ko ek chhoti floating window banake upar rakh sakte ho |
| **Daily Fix Timer** | **Permanent countdown** — default 10 h (1–24 h set kar sakte ho). Wall-clock se chalta hai: **stop/reset/close ka koi asar nahi**, app band ho ya phone band, time chalta hi rehta hai. **Roz midnight par full target ke saath wapas reset**. Ring me bacha hua time, neeche **Complete / Incomplete** (kitna ho gaya, kitna baki). 8 h / 10 h / 12 h chips ya +/− stepper se target badlo |

> **Overlay timer (Android):** Focus Timer par **Overlay** button dabao →
> pehli baar me phone ka "Display over other apps" permission khulega → allow
> karo → countdown ek chhota floating bubble ban ke doosre apps ke upar dikhta
> hai. Use me: **drag** se hila sakte ho, **Minimize (−)** se sirf ek chhota
> dot, tap karke wapas badha lo, **×** se poora band. Pehle se chal rahe timer
> ka time bhi overlay me live dikhta hai.
| **Live & Upcoming** | Task/event timers: live schedule slot ("LIVE · ends in"), agla slot, task alarm, event reminder — sab live countdown ke saath |
| **Upcoming test** | Agle mock test ka **bada countdown + status** (TODAY / TOMORROW / date·time), marks logged ho to score bhi |
| **Backlog** | Overdue tasks "overdue by X" countdown ke saath |
| **Progress log** | Syllabus ki live coverage — exam ke hisaab se, tap karke Syllabus kholo |

> **Focus timer ka DND mode:** jab timer chal raha ho aur Focus on ho, to saare
> alarms/sounds mute ho jaate hain (phone silent ho jaata hai tasks ke liye).
> Timer band hone par wapas normal.

---

## 5. To Do List — tasks manage karna

3 segments hain: **Today** (aaj ke), **Upcoming** (aane wale), **Backlog** (parked).

### Task add karna
1. Neeche wale box mein task likho.
2. Bucket chuno — **Today / Upcoming / Backlog** (chhipa hua diya hota hai, kholke change karo).
3. **Reminder** toggle karo to set time (clock icon se hour/minute), sound chuno.
4. Submit (arrow) dabao.

### Reminder / Alarm
- Har task par **reminder** laga sakte ho (time + sound).
- **Notification only** option: sirf silent notification + in-app popup — sound
  nahi bajta.
- Time aane par: **sound bajta hai + options dikhte hain** (Snooze etc.).
- Reminder wale tasks **Dashboard ke "Live & Upcoming"** me countdown ke saath
  dikhte hain.

### Task ke saath kya kya kar sakte ho
- **✓ circle** tap karo → complete.
- **Title tap** karo → rename.
- **⋮ (3-dot menu)** → Add to Backlog / Move to Today / Set reminder / Notification only / **Repeat daily** / Delete.
- **Today list me drag-and-drop** → long-press (mobile) ya mouse-se-khichkar
  (web) — priority order bana lo. Done tasks hamesha bottom par jate hain.
- **Backlog tasks** par tap → wapas Today me aa jaata hai.
- **Repeat daily (naya)** — "10 hr padhna", "maths ke 25 ques" jaise roz ke
  kaam: ⋮ menu → **Repeat daily** on karo. Jab task complete karte ho, uski
  **exact copy agle din automatically** ban jaati hai (same title, same alarm
  time) — roz add karne ki zaroorat nahi. Row par "Repeats daily" likha dikhta
  hai. (Duplicate copy tabhi banti hai jab complete karo — toggling se
  duplicate nahi banti.) Inke stats Stats tab ke "Daily habits" card me
  milte hain.

### Overdue rollover (important)
Agar koi task kal ka bacha hua hai aur aaj app kholi, to wo **automatic Today**
me aa jaata hai. Agar jaan-boojh kar Backlog me daala hai, to wahan pada rehta
hai (rollover usse nahi chhootta).

---

## 6. Calendar — mock tests aur markers

- **Month view** — saare marked days highlight hote hain.
- **Green days (naya)** — jis din us din ke tasks ke **goal number complete**
  ho jaate hain (default 3, Profile → streak goal me badal sakte ho), us date
  ka cell **green** + ✓ badge. Yehi din streak me count hote hain.
- **Day par tap** karo → **Day status window** khulti hai:
  - Day green hai → "Day complete — streak count hua" + done tasks ki list.
  - Day green nahi hai → "Green karne ke liye ye baaki hai" — pending tasks ki
    list (kyunki kaunsi tasks complete karni hain), aur `done of goal` counter.
  - Tasks neeche wali list me complete karke date green kar sakte ho.
- Us din ke tasks + options bhi neeche dikhte hain.
- **Mock test toggle** — kisi bhi din ko "mock test day" mark karo. Mark karne
  par:
  - **Dashboard ka "Upcoming test" card** us din ke liye countdown dikhata hai.
  - **Alarm** laga sakte ho (us waqt reminder fire hoga, title "Mock test").
- **Mock result (marks log)** — mock day par **marks/max** daalo (jaise 42/60).
  Ye Stats me trend chart + table + Weekly Review me dikhta hai.
- **Markers** — custom options bana sakte ho (jaise "Exam prep", "Revision") —
  Settings me naya option banao, color chuno, phir kisi bhi day par laga do.

---

## 7. Stats — progress dekhna

Sab graphs ek page par:

- **Pills** — total tasks done, streak, best streak, mock tests count, average %.
- **Streak card** — aaj kitne tasks kiye (goal ke against), +/− se goal change
  karo. Streak tabhi alive rehti hai jab daily goal poora karo.
- **Weekly stats** — bar chart (Mon–Sun), is week vs last week comparison.
- **Study time (naya)** — focus timer sessions ka 7-din ka chart — reset ke
  baad bhi daily kitna padha dikhta hai, hafte ka total bhi. Neeche **"Daily
  10 h goal"** progress bar — aaj ke time ka 10h ke against (ya jo bhi Daily
  Fix Timer ka target ho — Stats me bhi wahi target use hota hai).
- **Daily habits (naya)** — Repeat daily wale tasks (jaise "maths ke 25 ques")
  ka **last 7 days** ka dot chart + **streak** (🔥 N d) — habit circuit nazar
  aata hai.
- **Daily history** — pichhle 7 din, har din kitne tasks (✓ diya dikhta hai).
- **Weekly review** (naya feature):
  - Is week **kitna kiya** (tasks done)
  - **Kitna bacha** (still open + backlog count)
  - **Next 7 days ka plan** — aane wale tasks unki dates ke saath
  - **Mock marks log** — is week ke saare scores + week ka average
  - **Sunday** ko subtitle change ho jaata hai: "Sunday review — wrap up the
    week, plan ahead" — hafte ka summary nikalne ke liye perfect.
- **Mock test trend** — scores ka chart (last 6 attempts).
- **Mock test results** — pura log, newest first.
- **Exam coverage** — har exam ki syllabus completion %.

---

## 8. Schedule — weekly routine

- **Roz ka routine** banao: day (Mon–Sun) + time range (start–end) + title
  (jaise "DSA practice 6–7 PM").
- Ye slots **Dashboard ke "Live & Upcoming"** me live dikhte hain — slot ka
  time hua to "LIVE · ends in" countdown.
- Rename / delete slot par available.
- **12h / 24h format** yahin se choose hota hai.

---

## 9. Syllabus — exam-wise tracking

- **Exam → Unit → Chapter → Topic** ka tree structure.
- Har item par ✓ check karo — parent ke progress automatically update hote hain.
- **Exam date set** karo → Dashboard par countdown hero + Stats me coverage.
- **Revision reminders** — kisi item par revision reminder set kar sakte ho
  (spaced revision ke liye).
- Completion % har jagah dikhta hai (dashboard high-contrast card, stats).

---

## 10. Profile sheet (avatar chip)

Top-right avatar par tap karo. Yahan:

- **Theme** — 7 themes: Indigo, Ocean, Forest, Sunset, Rose, Midnight (dark) +
  light versions. **Midnight = dark mode** (raat ke liye, sab text white).
- **Dark mode quick toggle** — top bar ka 🌙/☀️ button Midnight on/off karta
  hai; off karne par **wahi light theme wapas** aa jaata hai jo pehle tha.
- **Daily goal** — roz kitne tasks karne hain (streak ke liye).
- **Daily plan notification** — roz ka plan reminder. Toggle on karne par
  **time picker khul jaata hai** — apne hisaab se time set karo (subah 7 baje
  "kal ka plan" ya raat 9 baje — jo routine suit kare). Time change karte hi
  next ring usi time par hota hai.
- **Backup & Restore**:
  - **Export data** → saara progress ek backup file (.json) me download ho
    jaata hai. File kahin safe rakho.
  - **Import data** → us file se wapas restore. **Phone badalne / data
    transfer** ke liye yahi tareeka hai.
- **Reset all data** — sab kuch saaf (tasks, schedule, mock marks, syllabus,
  countdowns). Dhyan se use karo — 2-step confirm hota hai.
- **About** — version, developer email: `zen201247007@gmail.com` (errors ya
  suggestions ke liye).

---

## 11. Right rail (bade screens)

- **Quick Memo** — chhote notes, local save, delete bhi kar sakte ho.
- **Deep Focus** — focus session timer (minutes select karke start).
- **Open To Do List** — ek tap me planner kholta hai.

---

## 12. Backup kaise karein (zaroori tip)

1. Profile (avatar) → **Export data** → file download hogi.
2. Naya phone / browser me: profile → **Import data** → file select karo.
3. Sab restore: tasks, marks, syllabus, streak — sab.

> Web version me data us browser ke storage me hota hai — doosre browser/device
> me same data nahi dikhega. Backup file hi transfer ka raasta hai.

---

## 13. Chhote tips

- **Streak mat todo** — daily goal poora karo, streak card se check karo.
- **Mock test ka pura use**: Calendar me day mark karo → Dashboard par
  countdown → test do → usi day par marks log karo → Stats me trend dekho.
- **Sunday ko Weekly Review kholo** — agle hafte ka plan banao, backlog clear
  karo.
- **Today list ko drag se prioritize karo** — sabse important kaam upar.
- **Raat ko Midnight theme** — aankhon ke liye aasan.
- Alarms ke liye **APK use karo** — phone me 100% reliable.

---

*App version 1.0.0 · developer: zen201247007@gmail.com*
