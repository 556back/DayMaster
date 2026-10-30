# Native bridge contract v1

Flutter MethodChannel: `daymaster/native`.

Snapshot JSON: `{version:1, events:[], widgets:[], settings:{themeMode:"system"}, updatedAt:"ISO8601"}`.

Event: `{id,title,date:"YYYY-MM-DD",category,emoji,colorHex:"#2864DC",note,photoBase64:null|string,repeatYearly:false,inclusive:false,pinned:false,reminderDays:null|0|1|3|7,createdAt:"ISO8601"}`.

Widget: `{id,style:"number"|"photo"|"dual"|"list"|"ring"|"calendar"|"ticket"|"bloom",eventIds:[id],theme:"blue"|"rose"|"green"|"ink"}`.

Optional widget appearance fields (v1 compatible): `backgroundOpacity:1` in0..1; `textTone:"auto"` in auto/light/dark; `photoScale:1` in1..3; `photoX:0,photoY:0` in-1..1; `photoDim:0.6` in0..0.85. Absent fields use these defaults. Flutter rejects malformed provided values on restore; native decoders use safe defaults/clamps defensively. Background, photo, shade, border and decorative art fade as one surface; primary/secondary date text remains independent. Light tone uses white text and a dark themed base; dark tone uses #18243A text and a light themed base. Photo shade is black for auto/light and white for dark, gradient alpha top=photoDim, bottom=min(0.9,photoDim+0.15). The default60% top shade keeps white titles readable even over a white photo; users can lower shade or surface opacity to suit their own wallpaper.

Photo cover geometry: factor=max(viewportWidth/sourceWidth,viewportHeight/sourceHeight)×photoScale; renderedLeft=(viewportWidth-sourceWidth×factor)×(photoX+1)/2; renderedTop similarly. Alignment -1 is left/top,0 centered,+1 right/bottom. Crop never exposes empty edges; source photos remain unmodified. WidgetKit can apply system tint/material or remove the container background; accessories/system-removed backgrounds use system foreground. Wallpaper preview images stay only in the editor and are not part of the snapshot.

Methods:
- `saveSnapshot` args `{json: String}`: atomically persist shared widget snapshot and refresh installed widgets; schedule reminders ONLY when already authorized. Return true; errors must propagate.
- `requestPinWidget` args `{configId:String}`: Android system pin request; returns bool for supported/requested, not installation completed. iOS returns false because users add from gallery.
- `requestNotifications` no args: user-triggered permission; bool authorized.
- `getLaunchEventId` no args: pending widget launch event ID or null.
- Native-to-Dart `openEvent` args `{id:String}` on a later launch.

Android package `com.daymaster.daymaster`; iOS bundle `com.daymaster.daymaster`; Widget app group `group.com.daymaster.daymaster` configurable before signing. iOS extension reads `snapshot.json` from shared App Group. Android reads local snapshot and configId mapped per appWidgetId. No server/network dependency for native widget data.

Civil day calculations: Gregorian, local date, normalized date difference; annual February29 falls back February28. Original date immutable. Inclusive adds1 only to count-up. Annual events can show elapsed since original plus days to next anniversary.

Images are base64 encoded compressed JPEG/PNG without data URL prefix. Maximum snapshot 20MiB; photo maximum1MiB. Invalid widget references render an add/open-app message rather than stale event contents. No hard-coded sample data in native widgets.

New styles: ring centers the event count inside the current Gregorian year progress ring (ordinal day including today / 365 or 366); calendar shows the current month Monday-first, distinguishes today, and marks the event target only within this month; ticket shows event direction/count and next target date with a perforation motif; bloom petals are decorative, with no event progress implication. All except list bind one event. Snapshot version remains1 and older four-style configurations stay valid.
