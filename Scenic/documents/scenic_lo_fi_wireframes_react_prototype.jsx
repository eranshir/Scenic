import React, { useState } from "react";
import {
  MapPin, Compass, Sun, Cloud, Camera, RouteIcon, Calendar as CalendarIcon, Upload,
  Bell, User, Image as ImageIcon, ThumbsUp, Filter, Search, List, Map as MapIcon,
  FileDown, Navigation, Home, PlusCircle, CalendarDays, BookOpen, User2, Settings as SettingsIcon
} from "lucide-react";

// Scenic — Lo‑Fi Mobile Wireframes (Dark • iPhone 15 Portrait)
// Tailwind-only prototype. Framed to 393×852 (iPhone 15 logical points).

// ---------------------------
// Utility UI bits
// ---------------------------
const Section = ({ title, right, children }) => (
  <div className="mb-4">
    <div className="flex items-center justify-between mb-2 px-1">
      <h3 className="text-[11px] font-semibold text-zinc-400 uppercase tracking-widest">{title}</h3>
      {right}
    </div>
    <div className="rounded-2xl border border-zinc-800 bg-zinc-900 p-3 shadow-sm">
      {children}
    </div>
  </div>
);

const Chip = ({ children }) => (
  <span className="inline-flex items-center gap-1 px-2 py-1 rounded-full border text-[10px] border-zinc-700 bg-zinc-800 text-zinc-200">{children}</span>
);

const Placeholder = ({ label, icon: Icon, h = "h-36" }) => (
  <div className={`flex flex-col items-center justify-center ${h} w-full rounded-xl border border-dashed border-zinc-700 text-zinc-500 bg-zinc-900`}>
    {Icon && <Icon className="h-5 w-5 mb-1" />}
    <span className="text-[11px]">{label}</span>
  </div>
);

const PlaceholderMap = () => (
  <div className="relative h-56 w-full rounded-2xl border border-dashed border-zinc-700 bg-[conic-gradient(at_25%_25%,_#18181b,_#111113)] overflow-hidden">
    <div className="absolute inset-0 grid grid-cols-12 grid-rows-12 opacity-20">
      {Array.from({ length: 144 }).map((_, i) => (
        <div key={i} className="border border-zinc-700/50"></div>
      ))}
    </div>
    <div className="absolute top-2 left-2 flex items-center gap-2">
      <Chip><MapIcon className="h-3 w-3"/> Map</Chip>
      <Chip><List className="h-3 w-3"/> Clusters</Chip>
    </div>
    <div className="absolute right-2 top-2 flex gap-2">
      <button className="px-2 py-1 text-[10px] rounded-lg bg-zinc-900/80 border border-zinc-700">+ / −</button>
      <button className="px-2 py-1 text-[10px] rounded-lg bg-zinc-900/80 border border-zinc-700">Locate</button>
    </div>
    {[...Array(7)].map((_, i) => (
      <div key={i} className="absolute bg-emerald-600/90 text-[10px] text-black px-2 py-1 rounded-full shadow"
           style={{ left: 16 + i * 36 + "px", top: 34 + (i % 3) * 44 + "px" }}>12</div>
    ))}
  </div>
);

// ---------------------------
// App Bars & Tab Bars (mobile)
// ---------------------------
const AppBar = ({ title, onBell, onSettings }) => (
  <div className="h-12 px-3 flex items-center justify-between border-b border-zinc-800 bg-black/60 backdrop-blur">
    <div className="flex items-center gap-2">
      <div className="h-7 w-7 rounded-xl bg-emerald-500 text-black flex items-center justify-center font-bold">S</div>
      <div className="font-semibold text-zinc-100 text-sm">{title}</div>
    </div>
    <div className="flex items-center gap-2">
      {onBell && <button className="p-1.5 rounded-lg border border-zinc-800"><Bell className="h-4 w-4 text-zinc-300"/></button>}
      {onSettings && <button className="p-1.5 rounded-lg border border-zinc-800"><SettingsIcon className="h-4 w-4 text-zinc-300"/></button>}
    </div>
  </div>
);

const TabButton = ({ active, label, Icon, onClick }) => (
  <button onClick={onClick} className="flex flex-1 flex-col items-center justify-center py-1">
    <Icon className={`h-5 w-5 ${active ? 'text-emerald-400' : 'text-zinc-400'}`}/>
    <span className={`text-[10px] mt-0.5 ${active ? 'text-emerald-400' : 'text-zinc-400'}`}>{label}</span>
  </button>
);

const TabBar = ({ tab, setTab }) => (
  <div className="h-14 border-t border-zinc-800 bg-black/70 backdrop-blur flex">
    <TabButton active={tab==='home'} label="Home" Icon={Home} onClick={()=>setTab('home')}/>
    <TabButton active={tab==='plans'} label="Plans" Icon={CalendarDays} onClick={()=>setTab('plans')}/>
    <TabButton active={tab==='add'} label="Add" Icon={PlusCircle} onClick={()=>setTab('add')}/>
    <TabButton active={tab==='journal'} label="Journal" Icon={BookOpen} onClick={()=>setTab('journal')}/>
    <TabButton active={tab==='profile'} label="Profile" Icon={User2} onClick={()=>setTab('profile')}/>
  </div>
);

// ---------------------------
// Screens (mobile, dark)
// ---------------------------
const ToolbarFilters = () => (
  <div className="flex flex-wrap items-center gap-2">
    <div className="flex items-center gap-2 px-3 py-2 border rounded-xl bg-zinc-900 border-zinc-800 w-full">
      <Search className="h-4 w-4 text-zinc-400"/>
      <input className="outline-none text-sm bg-transparent placeholder:text-zinc-500 flex-1" placeholder="Search region or spot…"/>
      <button className="text-xs px-2 py-1 rounded-lg border border-zinc-800">Go</button>
    </div>
    <div className="flex gap-2">
      <Chip><Sun className="h-3 w-3"/> Golden/Blue</Chip>
      <Chip><Cloud className="h-3 w-3"/> Clear • Fog</Chip>
      <Chip><Navigation className="h-3 w-3"/> Difficulty</Chip>
      <Chip><ThumbsUp className="h-3 w-3"/> Popular</Chip>
      <button className="px-3 py-2 text-xs rounded-xl border border-zinc-800 bg-zinc-900 text-zinc-200 flex items-center gap-2"><Filter className="h-4 w-4"/> More</button>
    </div>
  </div>
);

const HomeScreen = ({ goSpot }) => {
  const [mode, setMode] = useState('map');
  return (
    <div className="p-3 pb-16">{/* padding bottom for tab bar */}
      <ToolbarFilters/>
      <div className="mt-3 flex items-center gap-2">
        <button onClick={()=>setMode('map')} className={`px-3 py-2 rounded-xl text-xs border ${mode==='map'?'bg-emerald-500 text-black border-emerald-500':'bg-zinc-900 border-zinc-800 text-zinc-200'}`}><MapIcon className="inline h-4 w-4 mr-1"/>Map</button>
        <button onClick={()=>setMode('feed')} className={`px-3 py-2 rounded-xl text-xs border ${mode==='feed'?'bg-emerald-500 text-black border-emerald-500':'bg-zinc-900 border-zinc-800 text-zinc-200'}`}><List className="inline h-4 w-4 mr-1"/>Feed</button>
      </div>
      {mode==='map' ? (
        <Section title="Explore on Map" right={<Chip><MapPin className="h-3 w-3"/> Current region</Chip>}>
          <PlaceholderMap/>
        </Section>
      ) : (
        <Section title="Explore Feed">
          <div className="grid grid-cols-1 gap-3">
            {[...Array(6)].map((_, i) => (
              <div key={i} className="rounded-2xl border border-dashed border-zinc-700 p-3 bg-zinc-900">
                <Placeholder label="Hero Media" icon={ImageIcon} h="h-40"/>
                <div className="mt-2 flex items-center justify-between">
                  <div className="text-sm font-medium text-zinc-100">Sunrise • Lago di Braies</div>
                  <button onClick={goSpot} className="text-[11px] px-2 py-1 rounded-lg border border-zinc-800">Open</button>
                </div>
                <div className="mt-1 flex items-center gap-2 text-[11px] text-zinc-400">
                  <MapPin className="h-3 w-3"/> 46.69, 12.07 <Compass className="h-3 w-3"/> 78°
                </div>
              </div>
            ))}
          </div>
        </Section>
      )}
    </div>
  )
};

const SunWeatherRow = () => (
  <div className="grid grid-cols-2 gap-2 text-[11px]">
    <div className="rounded-lg border border-zinc-800 p-3 bg-zinc-900">
      <div className="flex items-center gap-2 font-medium text-zinc-100"><Sun className="h-4 w-4"/> Sunrise / Sunset</div>
      <div className="mt-1 text-zinc-300">05:48 / 20:32 (local)</div>
      <div className="mt-1 text-zinc-400">Golden: 05:15–06:10 • 19:50–21:05</div>
    </div>
    <div className="rounded-lg border border-zinc-800 p-3 bg-zinc-900">
      <div className="flex items-center gap-2 font-medium text-zinc-100"><Cloud className="h-4 w-4"/> Weather Snapshot</div>
      <div className="mt-1 text-zinc-300">Clear • 14°C • Wind 2m/s</div>
      <div className="mt-1 text-zinc-400">Clouds 10% • Vis 10km</div>
    </div>
    <div className="rounded-lg border border-zinc-800 p-3 bg-zinc-900">
      <div className="flex items-center gap-2 font-medium text-zinc-100"><Compass className="h-4 w-4"/> Heading</div>
      <div className="mt-1 text-zinc-300">78° (ENE)</div>
      <div className="mt-1 text-zinc-400">Relative to sunrise: −22m</div>
    </div>
    <div className="rounded-lg border border-zinc-800 p-3 bg-zinc-900">
      <div className="flex items-center gap-2 font-medium text-zinc-100"><MapPin className="h-4 w-4"/> Coordinates</div>
      <div className="mt-1 text-zinc-300">46.6921, 12.0690</div>
      <div className="mt-1 text-zinc-400">Copy • Share • GPX</div>
    </div>
  </div>
);

const SpotDetail = () => (
  <div className="p-3 pb-16">
    <Section title="Hero Media">
      <Placeholder label="Image/Video Carousel" icon={ImageIcon} h="h-48"/>
    </Section>
    <Section title="Essentials"><SunWeatherRow/></Section>
    <Section title="Parking & Route" right={<button className="px-3 py-1.5 text-[11px] rounded-xl border border-zinc-800">Open Map</button>}>
      <div className="grid grid-cols-1 gap-3">
        <Placeholder label="Mini Map with Route" icon={RouteIcon} h="h-40"/>
        <div className="grid gap-2 text-[12px]">
          <div className="rounded-lg border border-zinc-800 p-3 bg-zinc-900">
            <div className="font-medium text-zinc-100">Route Summary</div>
            <div className="mt-1 text-zinc-300">2.1km • 140m gain • 45m</div>
            <div className="mt-1 text-zinc-400">Hazards: narrow ledge near viewpoint; Fees: parking €6</div>
            <div className="mt-2 flex gap-2">
              <button className="px-3 py-1.5 text-[11px] rounded-xl border border-zinc-800">Export GPX</button>
              <button className="px-3 py-1.5 text-[11px] rounded-xl border border-zinc-800">Copy Parking</button>
            </div>
          </div>
          <div className="rounded-lg border border-zinc-800 p-3 bg-zinc-900">
            <div className="font-medium text-zinc-100">Tips & Logistics</div>
            <ul className="mt-1 list-disc pl-5 text-zinc-300">
              <li>Arrive 45m before sunrise; tripod + ND recommended.</li>
              <li>Best calm reflections after wind dies (usually 06:10–06:30).</li>
              <li>Avoid weekends; rangers close access after 09:00.</li>
            </ul>
          </div>
        </div>
      </div>
    </Section>
    <Section title="EXIF / Capture Settings">
      <div className="grid grid-cols-2 gap-2 text-[11px]">
        {[["Device","Sony A7 IV"],["Lens","16–35mm"],["Focal","16mm"],["Aperture","f/8"],["Shutter","1/4s"],["ISO","100"]].map(([k,v]) => (
          <div key={k} className="rounded-lg border border-zinc-800 p-3 bg-zinc-900">
            <div className="text-zinc-400">{k}</div>
            <div className="font-medium text-zinc-100">{v}</div>
          </div>
        ))}
      </div>
    </Section>
    <Section title="Comments & Gallery from this Spot">
      <div className="grid grid-cols-1 gap-3">
        {[...Array(2)].map((_,i)=> (
          <div key={i} className="rounded-xl border border-zinc-800 p-3 bg-zinc-900">
            <div className="flex items-center gap-2 text-sm text-zinc-200"><User className="h-4 w-4"/> @noa • 2d ago</div>
            <div className="mt-2 text-zinc-300 text-[13px]">Great angle by stepping 2m left of main rock; avoids crowd line.</div>
            <div className="mt-2 flex gap-3 text-[11px] text-zinc-400"><button className="px-2 py-1 rounded-lg border border-zinc-800"><ThumbsUp className="h-3 w-3 inline mr-1"/> 24</button><button className="px-2 py-1 rounded-lg border border-zinc-800">Reply</button></div>
          </div>
        ))}
        <div className="grid grid-cols-2 gap-2">
          {[...Array(4)].map((_,i)=> <Placeholder key={i} label="Alt Result" icon={ImageIcon} h="h-24"/>) }
        </div>
      </div>
    </Section>
  </div>
);

const AddSpotFlow = () => {
  const [step, setStep] = useState(1); // 1 Media, 2 Meta, 3 Route, 4 Tips
  return (
    <div className="p-3 pb-16">
      <div className="flex items-center gap-2">
        {[1,2,3,4].map(n => (
          <div key={n} className={`px-3 py-1 rounded-full text-[10px] border ${step===n? 'bg-emerald-500 text-black border-emerald-500':'bg-zinc-900 text-zinc-200 border-zinc-800'}`}>Step {n}</div>
        ))}
        <div className="text-[12px] text-zinc-400">{step===1?'Media Picker':step===2?'Metadata Confirm':step===3?'Parking & Route':'Tips & Publish'}</div>
      </div>

      {step===1 && (
        <Section title="Select Media">
          <div className="grid grid-cols-3 gap-2">
            {[...Array(12)].map((_,i)=> <Placeholder key={i} label="Photo/Video" icon={Camera} h="h-24"/>)}
          </div>
          <div className="mt-3 flex justify-end"><button onClick={()=>setStep(2)} className="px-4 py-2 rounded-xl bg-emerald-500 text-black">Continue</button></div>
        </Section>
      )}
      {step===2 && (
        <Section title="Confirm Metadata">
          <div className="grid grid-cols-1 gap-3">
            <div className="rounded-xl border border-zinc-800 p-3 bg-zinc-900 text-[12px]">
              <div className="font-medium mb-2 text-zinc-100">Auto‑extracted</div>
              <div className="grid grid-cols-2 gap-2 text-[11px]">
                <label className="flex flex-col">GPS<input className="mt-1 px-2 py-1 border rounded bg-black/30 border-zinc-800" defaultValue="46.6921, 12.0690"/></label>
                <label className="flex flex-col">Time (UTC)<input className="mt-1 px-2 py-1 border rounded bg.black/30 border-zinc-800" defaultValue="2025‑06‑14 03:25"/></label>
                <label className="flex flex-col">Device<input className="mt-1 px-2 py-1 border rounded bg-black/30 border-zinc-800" defaultValue="iPhone 15 Pro"/></label>
                <label className="flex flex-col">Lens<input className="mt-1 px-2 py-1 border rounded bg-black/30 border-zinc-800" defaultValue="24mm equiv"/></label>
              </div>
            </div>
            <div className="rounded-xl border border-zinc-800 p-3 bg-zinc-900 text-[12px]">
              <div className="font-medium mb-2 text-zinc-100">Sun & Weather</div>
              <div className="text-zinc-300">Closest: Sunrise (−22m) • Golden 05:15–06:10</div>
              <div className="text-zinc-300 mt-1">Clear • 14°C • Wind 2m/s</div>
            </div>
            <div className="grid gap-3">
              <Placeholder label="Capture Point (Adjustable)" icon={MapPin} h="h-40"/>
              <div className="flex items-center justify-between">
                <span className="text-sm text-zinc-300">Heading: 78°</span>
                <input type="range" min={0} max={359} defaultValue={78} className="w-1/2"/>
              </div>
            </div>
          </div>
          <div className="mt-3 flex justify-between">
            <button onClick={()=>setStep(1)} className="px-4 py-2 rounded-xl border border-zinc-800">Back</button>
            <button onClick={()=>setStep(3)} className="px-4 py-2 rounded-xl bg-emerald-500 text-black">Continue</button>
          </div>
        </Section>
      )}
      {step===3 && (
        <Section title="Parking & Route">
          <div className="grid grid-cols-1 gap-3">
            <Placeholder label="Draw/Record Route" icon={RouteIcon} h="h-40"/>
            <div className="grid gap-2 text-[11px]">
              <div className="grid grid-cols-3 gap-2">
                <label className="flex flex-col">Start<select className="mt-1 px-2 py-1 border rounded bg-black/30 border-zinc-800"><option>Parking</option><option>POI</option></select></label>
                <label className="flex flex-col">Difficulty<select className="mt-1 px-2 py-1 border rounded bg-black/30 border-zinc-800"><option>Easy</option><option>Moderate</option><option>Hard</option></select></label>
                <label className="flex flex-col">Distance (km)<input className="mt-1 px-2 py-1 border rounded bg-black/30 border-zinc-800" defaultValue="2.1"/></label>
              </div>
              <textarea className="mt-1 px-2 py-2 border rounded text-sm bg-black/30 border-zinc-800" placeholder="Notes, hazards, fees…"/>
            </div>
          </div>
          <div className="mt-3 flex justify-between">
            <button onClick={()=>setStep(2)} className="px-4 py-2 rounded-xl border border-zinc-800">Back</button>
            <button onClick={()=>setStep(4)} className="px-4 py-2 rounded-xl bg-emerald-500 text-black">Continue</button>
          </div>
        </Section>
      )}
      {step===4 && (
        <Section title="Tips & Publish">
          <div className="grid grid-cols-1 gap-3">
            <div className="space-y-2">
              <label className="text-sm text-zinc-300">What were you trying to achieve?</label>
              <textarea className="w-full px-3 py-2 border rounded bg-black/30 border-zinc-800" rows={4} placeholder="e.g., mirror‑like reflections with leading lines"/>
              <label className="text-sm text-zinc-300">Composition & shooting tips</label>
              <textarea className="w-full px-3 py-2 border rounded bg-black/30 border-zinc-800" rows={4} placeholder="Tripod, ND 6‑stop, shoot at f/8, 1/4s"/>
            </div>
            <div className="space-y-2">
              <label className="text-sm text-zinc-300">Logistics</label>
              <textarea className="w-full px-3 py-2 border rounded bg-black/30 border-zinc-800" rows={4} placeholder="Arrive 45m before sunrise; parking fills fast"/>
              <div className="flex items-center gap-3 text-sm text-zinc-300"><input type="checkbox"/> Public <input type="checkbox"/> CC‑BY‑NC</div>
            </div>
            <div className="space-y-2">
              <Placeholder label="Upload Progress" icon={Upload} h="h-24"/>
              <button className="w-full px-4 py-2 rounded-xl bg-emerald-500 text-black">Publish</button>
            </div>
          </div>
          <div className="mt-3 flex justify-between">
            <button onClick={()=>setStep(3)} className="px-4 py-2 rounded-xl border border-zinc-800">Back</button>
            <button className="px-4 py-2 rounded-xl border border-zinc-800">Save Draft</button>
          </div>
        </Section>
      )}
    </div>
  );
};

const PlansScreen = () => (
  <div className="p-3 pb-16">
    <Section title="Planner">
      <div className="grid grid-cols-1 gap-3">
        <div className="rounded-xl border border-zinc-800 p-3 bg-zinc-900 text-sm">
          <div className="flex items-center justify-between"><div className="font-medium flex items-center gap-2 text-zinc-100"><CalendarIcon className="h-4 w-4"/> Date</div><button className="px-2 py-1 text-[11px] rounded-lg border border-zinc-800">Change</button></div>
          <div className="mt-2 text-zinc-300">May 16, 2026 (UTC+2)</div>
          <div className="mt-2 text-zinc-400">Sunrise 05:48 • Sunset 20:32</div>
        </div>
        <div className="rounded-xl border border-zinc-800 p-3 bg-zinc-900 text-sm">
          <div className="font-medium text-zinc-100">Offline Pack</div>
          <div className="mt-1 text-zinc-300">Tiles + metadata + thumbnails</div>
          <button className="mt-2 px-3 py-2 rounded-xl border border-zinc-800">Download</button>
        </div>
        <Placeholder label="Day Timeline (Golden/Blue bars, chips)" icon={CalendarIcon} h="h-28"/>
        <div className="grid grid-cols-1 gap-2 text-sm">
          {["Sunrise Spot","Midday Alt","Sunset Primary","Blue Hour City"].map((name,i)=> (
            <div key={i} className="rounded-lg border border-zinc-800 p-3 bg-zinc-900 flex items-center justify-between">
              <div>
                <div className="font-medium text-zinc-100">{name}</div>
                <div className="text-[11px] text-zinc-400">Drive 35m • Hike 20m</div>
              </div>
              <div className="flex gap-2"><button className="px-2 py-1 text-[11px] rounded-lg border border-zinc-800">Open</button><button className="px-2 py-1 text-[11px] rounded-lg border border-zinc-800">Remove</button></div>
            </div>
          ))}
        </div>
        <div className="flex gap-2"><button className="px-3 py-2 rounded-xl border border-zinc-800">Add Spot</button><button className="px-3 py-2 rounded-xl border border-zinc-800">Auto‑Fit</button><button className="px-3 py-2 rounded-xl border border-zinc-800"><FileDown className="h-4 w-4 inline mr-1"/> GPX</button></div>
      </div>
    </Section>
  </div>
);

const JournalScreen = () => (
  <div className="p-3 pb-16">
    <Section title="My Map"><PlaceholderMap/></Section>
    <Section title="Stats">
      <div className="grid grid-cols-2 gap-2 text-sm">
        {[['Spots Logged','42'],['Golden Hits','18'],['Subjects','7'],['Gear Used','3 bodies / 6 lenses']].map(([k,v])=> (
          <div key={k} className="rounded-lg border border-zinc-800 p-3 bg-zinc-900"><div className="text-zinc-400">{k}</div><div className="font-medium text-zinc-100">{v}</div></div>
        ))}
      </div>
      <div className="mt-3 flex gap-2"><button className="px-3 py-2 rounded-xl border border-zinc-800">Export CSV</button><button className="px-3 py-2 rounded-xl border border-zinc-800">Export GPX</button></div>
    </Section>
  </div>
);

const ProfileScreen = () => (
  <div className="p-3 pb-16">
    <Section title="Profile">
      <div className="flex items-center gap-3">
        <div className="h-12 w-12 rounded-full bg-zinc-700 border border-zinc-600"/>
        <div>
          <div className="font-semibold text-zinc-100">@eran • Explorer</div>
          <div className="text-[12px] text-zinc-400">Reputation 1,240 • Spots 23</div>
        </div>
        <div className="ml-auto flex gap-2"><button className="px-3 py-2 rounded-xl border border-zinc-800">Share</button><button className="px-3 py-2 rounded-xl border border-zinc-800">Follow</button></div>
      </div>
    </Section>
    <Section title="Badges & Titles">
      <div className="flex flex-wrap gap-2 text-[11px]">
        {["Explorer","Cartographer","Guide","Trailblazer"].map(b => <Chip key={b}>{b}</Chip>)}
      </div>
    </Section>
    <Section title="Contributions">
      <div className="grid grid-cols-2 gap-2">
        {[...Array(6)].map((_,i)=> <Placeholder key={i} label="Spot Card" icon={ImageIcon} h="h-24"/>) }
      </div>
    </Section>
  </div>
);

const NotificationsScreen = () => (
  <div className="p-3 pb-16">
    {[{t:"New comment on your spot", s:"Lago di Braies", ago:"2h"},{t:"Weather alert for saved plan", s:"Dolomites day 3", ago:"6h"},{t:"Your photo was upvoted", s:"Tre Cime Sunrise", ago:"1d"}].map((n,i)=> (
      <div key={i} className="rounded-xl border border-zinc-800 p-3 bg-zinc-900 flex items-center gap-3 mb-2">
        <Bell className="h-5 w-5 text-zinc-300"/>
        <div className="flex-1">
          <div className="text-sm font-medium text-zinc-100">{n.t}</div>
          <div className="text-[11px] text-zinc-400">{n.s} • {n.ago} ago</div>
        </div>
        <button className="px-3 py-2 rounded-xl border border-zinc-800">Open</button>
      </div>
    ))}
  </div>
);

const SettingsScreen = () => (
  <div className="p-3 pb-16">
    <Section title="Permissions">
      <div className="grid grid-cols-1 gap-2 text-sm">
        {["Photos","Location","Notifications"].map(x => (
          <div key={x} className="rounded-lg border border-zinc-800 p-3 bg-zinc-900 flex items-center justify-between"><span className="text-zinc-200">{x}</span><button className="px-3 py-2 rounded-xl border border-zinc-800">Manage</button></div>
        ))}
      </div>
    </Section>
    <Section title="Data & Privacy">
      <div className="grid gap-2 text-sm">
        <div className="rounded-lg border border-zinc-800 p-3 bg-zinc-900 flex items-center justify-between"><span className="text-zinc-200">Export my data (CSV/GPX)</span><button className="px-3 py-2 rounded-xl border border-zinc-800">Export</button></div>
        <div className="rounded-lg border border-zinc-800 p-3 bg-zinc-900 flex items-center justify-between"><span className="text-zinc-200">Delete account & content</span><button className="px-3 py-2 rounded-xl border border-zinc-800">Request</button></div>
      </div>
    </Section>
  </div>
);

// ---------------------------
// Device Frame (iPhone 15 portrait)
// ---------------------------
const DeviceFrame = ({ children }) => (
  <div className="mx-auto my-3 flex justify-center">
    <div className="relative w-[393px] h-[852px] rounded-[2.2rem] bg-black shadow-2xl ring-8 ring-neutral-950 overflow-hidden">
      {/* Faux notch/status area */}
      <div className="absolute top-0 inset-x-0 h-8 bg-black z-30" />
      <div className="absolute top-0 left-1/2 -translate-x-1/2 w-40 h-7 bg-black rounded-b-3xl z-40" />
      {/* Screen */}
      <div className="relative h-full flex flex-col bg-gradient-to-b from-neutral-950 to-black text-zinc-100">
        {children}
      </div>
    </div>
  </div>
);

// ---------------------------
// Root App (with prototype controls on top)
// ---------------------------
export default function App() {
  const [tab, setTab] = useState("home");
  const [overlay, setOverlay] = useState("none");
  const [routeScreen, setRouteScreen] = useState("home"); // internal screen (e.g., spot)

  return (
    <div className="min-h-screen bg-neutral-950 text-zinc-100">
      {/* Prototype controls (outside device) */}
      <div className="max-w-5xl mx-auto px-4 pt-4">
        <div className="mb-3 flex items-center justify-between">
          <div className="text-sm text-zinc-400">Scenic — Mobile Lo‑Fi • Dark • iPhone 15 frame</div>
          <div className="flex items-center gap-2 text-xs">
            <button className={`px-3 py-1 rounded-lg border ${overlay==='none'?'border-emerald-500 text-emerald-400':'border-zinc-700 text-zinc-300'}`} onClick={()=>setOverlay('none')}>Default</button>
            <button className={`px-3 py-1 rounded-lg border ${overlay==='notif'?'border-emerald-500 text-emerald-400':'border-zinc-700 text-zinc-300'}`} onClick={()=>setOverlay('notif')}>Notifications</button>
            <button className={`px-3 py-1 rounded-lg border ${overlay==='settings'?'border-emerald-500 text-emerald-400':'border-zinc-700 text-zinc-300'}`} onClick={()=>setOverlay('settings')}>Settings</button>
          </div>
        </div>
      </div>

      <DeviceFrame>
        {/* App bar varies by route */}
        {routeScreen === 'home' && <AppBar title="Scenic" onBell={() => setOverlay('notif')} onSettings={() => setOverlay('settings')} />}
        {routeScreen === 'spot' && <AppBar title="Spot Detail" onBell={() => setOverlay('notif')} onSettings={() => setOverlay('settings')} />}
        {routeScreen === 'add' && <AppBar title="Add Spot" onBell={() => setOverlay('notif')} onSettings={() => setOverlay('settings')} />}
        {routeScreen === 'plans' && <AppBar title="Plans" onBell={() => setOverlay('notif')} onSettings={() => setOverlay('settings')} />}
        {routeScreen === 'journal' && <AppBar title="Journal" onBell={() => setOverlay('notif')} onSettings={() => setOverlay('settings')} />}
        {routeScreen === 'profile' && <AppBar title="Profile" onBell={() => setOverlay('notif')} onSettings={() => setOverlay('settings')} />}

        {/* Screen body */}
        <div className="flex-1 overflow-y-auto">
          {routeScreen === 'home' && <HomeScreen goSpot={() => setRouteScreen('spot')} />}
          {routeScreen === 'spot' && <SpotDetail />}
          {routeScreen === 'add' && <AddSpotFlow />}
          {routeScreen === 'plans' && <PlansScreen />}
          {routeScreen === 'journal' && <JournalScreen />}
          {routeScreen === 'profile' && <ProfileScreen />}
          {overlay === 'notif' && <NotificationsScreen />}
          {overlay === 'settings' && <SettingsScreen />}
        </div>

        {/* Tab bar (persistent) */}
        <TabBar tab={tab} setTab={(t)=>{ setTab(t); setRouteScreen(t); setOverlay('none'); }} />
      </DeviceFrame>
    </div>
  );
}
