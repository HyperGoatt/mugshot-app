import { useMemo, useState } from "react";
import {
  AlertTriangle,
  ArrowDownUp,
  ArrowLeft,
  BatteryFull,
  Bookmark,
  Check,
  ChevronDown,
  ChevronRight,
  CircleAlert,
  CirclePlus,
  Clock3,
  Coffee,
  Copy,
  ExternalLink,
  Eye,
  FileWarning,
  Filter,
  Heart,
  History,
  Layers3,
  List,
  ListFilter,
  LoaderCircle,
  LocateFixed,
  LockKeyhole,
  Map,
  MapPin,
  MoreHorizontal,
  Navigation,
  NotebookPen,
  RefreshCw,
  RotateCcw,
  Search,
  Share2,
  Signal,
  Sparkles,
  Star,
  UserRound,
  Wifi,
  WifiOff,
  X,
} from "lucide-react";
import { KeyboardInput } from "../mobile";
import {
  allCafeOrder,
  cafes,
  favoriteCafeOrder,
  recentSips,
  socialActivity,
  wantToTryCafeOrder,
  type CafeFixture,
  type ScreenId,
} from "./data";

type NavigateTarget = ScreenId | "filters" | "sort" | "search" | "list" | "map" | "detail" | "expand" | "close";

type PhoneScreenProps = {
  id: ScreenId;
  interactive?: boolean;
  onNavigate?: (target: NavigateTarget) => void;
};

type CafeCardProps = {
  cafe: CafeFixture;
  compact?: boolean;
  accessibility?: boolean;
  syncing?: boolean;
  failed?: boolean;
  favoriteOverride?: boolean;
  onOpen?: () => void;
  onFavorite?: () => void;
};

const screenTitleBySection = {
  favorites: "Favorites",
  wantToTry: "Want to Try",
  all: "All Cafes",
};

function ArtifactStatusBar() {
  return (
    <div className="mg-status-bar" aria-label="9:41, Wi-Fi, full battery">
      <span className="mg-status-time">9:41</span>
      <span className="mg-status-icons" aria-hidden="true">
        <Signal size={16} strokeWidth={2.3} />
        <Wifi size={16} strokeWidth={2.3} />
        <BatteryFull size={20} strokeWidth={2.1} />
      </span>
    </div>
  );
}

function Segmented({
  labels,
  selected,
  ariaLabel,
  onSelect,
  className = "",
}: {
  labels: string[];
  selected: string;
  ariaLabel: string;
  onSelect?: (label: string) => void;
  className?: string;
}) {
  return (
    <div className={`mg-segmented ${className}`} role="tablist" aria-label={ariaLabel}>
      {labels.map((label) => (
        <button
          className="mg-segment"
          data-selected={selected === label ? "true" : "false"}
          key={label}
          role="tab"
          aria-selected={selected === label}
          onClick={() => onSelect?.(label)}
        >
          {label}
        </button>
      ))}
    </div>
  );
}

function SearchField({
  value = "",
  focused = false,
  interactive = false,
  placeholder = "Search your cafes",
  onFocus,
}: {
  value?: string;
  focused?: boolean;
  interactive?: boolean;
  placeholder?: string;
  onFocus?: () => void;
}) {
  return (
    <div className="mg-search-field" data-focused={focused ? "true" : "false"}>
      <Search size={18} aria-hidden="true" />
      {interactive ? (
        <KeyboardInput
          aria-label="Search your cafes"
          defaultValue={value}
          placeholder={placeholder}
          onFocus={onFocus}
        />
      ) : (
        <span className={value ? "mg-search-value" : "mg-search-placeholder"}>{value || placeholder}</span>
      )}
      {value ? (
        <button className="mg-inline-icon" aria-label="Clear search">
          <X size={16} />
        </button>
      ) : null}
    </div>
  );
}

function CafeImage({ cafe, className = "" }: { cafe: CafeFixture; className?: string }) {
  if (cafe.photoState === "loaded" && cafe.image) {
    return <img className={`mg-cafe-image ${className}`} src={cafe.image} alt={`${cafe.name} interior`} />;
  }

  if (cafe.photoState === "failed") {
    return (
      <div className={`mg-cafe-image mg-image-failed ${className}`} aria-label="Cafe photo unavailable">
        <FileWarning size={24} aria-hidden="true" />
        <span>Retry photo</span>
      </div>
    );
  }

  return (
    <div className={`mg-cafe-image mg-image-missing ${className}`} aria-label="No cafe photo yet">
      <img src="/assets/mugshot/mugsy-cafes.png" alt="" aria-hidden="true" />
      <span>No photo yet</span>
    </div>
  );
}

function MembershipLine({ cafe }: { cafe: CafeFixture }) {
  const reasons = [
    cafe.memberships.includes("favorite") ? "Favorite" : null,
    cafe.memberships.includes("wantToTry") ? "Want to Try" : null,
    cafe.memberships.includes("visited") ? "Visited" : null,
  ].filter(Boolean);

  return <span className="mg-membership-line">{reasons.join(" · ")}</span>;
}

function CafeCard({
  cafe,
  compact = false,
  accessibility = false,
  syncing = false,
  failed = false,
  favoriteOverride,
  onOpen,
  onFavorite,
}: CafeCardProps) {
  const isFavorite = favoriteOverride ?? cafe.memberships.includes("favorite");
  const isWantToTry = cafe.memberships.includes("wantToTry");
  const scoreText = cafe.personalScore ? `You ${cafe.personalScore.toFixed(1)}` : "Not rated";
  const sipText = cafe.sipCount === 0 ? "No sips yet" : `${cafe.sipCount} ${cafe.sipCount === 1 ? "sip" : "sips"}`;
  const location = cafe.neighborhood ?? "Location unavailable";
  const ariaLabel = `${cafe.name}, ${location}${cafe.distance ? `, ${cafe.distance}` : ""}, ${scoreText}, ${sipText}, ${isFavorite ? "Favorite" : "Not Favorite"}.`;

  return (
    <article
      className={`mg-cafe-card ${compact ? "mg-cafe-card-compact" : ""} ${accessibility ? "mg-cafe-card-accessibility" : ""}`}
      aria-label={ariaLabel}
    >
      <button className="mg-card-open" onClick={onOpen} aria-label={`Open ${cafe.name} details`}>
        <CafeImage cafe={cafe} />
        <span className="mg-card-copy">
          <span className="mg-card-name">{cafe.name}</span>
          <span className="mg-card-location">
            {location}
            {cafe.distance ? ` · ${cafe.distance}` : ""}
          </span>
          <span className="mg-card-signal">
            {scoreText} · {sipText}
          </span>
          <MembershipLine cafe={cafe} />
        </span>
      </button>
      <div className="mg-card-state-controls">
        <button
          className="mg-favorite-control"
          data-selected={isFavorite ? "true" : "false"}
          data-syncing={syncing ? "true" : "false"}
          aria-label={`Favorite ${cafe.name}`}
          aria-pressed={isFavorite}
          onClick={onFavorite}
        >
          {syncing ? <LoaderCircle className="mg-spin" size={19} /> : <Heart size={19} fill={isFavorite ? "currentColor" : "none"} />}
        </button>
        <button
          className="mg-wtt-control"
          data-selected={isWantToTry ? "true" : "false"}
          aria-label={`Want to Try ${cafe.name}`}
          aria-pressed={isWantToTry}
        >
          <Bookmark size={19} fill={isWantToTry ? "currentColor" : "none"} />
        </button>
      </div>
      {!compact ? (
        <div className="mg-card-footer">
          <button className="mg-card-log">
            <CirclePlus size={18} />
            Log a Sip
          </button>
          <button className="mg-card-more" aria-label={`More actions for ${cafe.name}`}>
            <MoreHorizontal size={20} />
          </button>
        </div>
      ) : (
        <button className="mg-row-more" aria-label={`More actions for ${cafe.name}`}>
          <MoreHorizontal size={20} />
        </button>
      )}
      {failed ? (
        <div className="mg-card-error">
          <CircleAlert size={15} /> Favorite wasn’t saved. <strong>Retry</strong>
        </div>
      ) : null}
    </article>
  );
}

function SavedHeader({
  section = "favorites",
  query = "",
  focused = false,
  interactive = false,
  filterCount = 0,
  density = "comfortable",
  resultCount,
  status,
  onNavigate,
}: {
  section?: "favorites" | "wantToTry" | "all";
  query?: string;
  focused?: boolean;
  interactive?: boolean;
  filterCount?: number;
  density?: "comfortable" | "compact";
  resultCount: number;
  status?: React.ReactNode;
  onNavigate?: (target: NavigateTarget) => void;
}) {
  const selectedSection = screenTitleBySection[section];
  return (
    <header className="mg-saved-header">
      <h1>Saved</h1>
      <p>Your personal cafe library</p>
      <Segmented labels={["Cafes", "Lists"]} selected="Cafes" ariaLabel="Saved content" />
      <Segmented
        labels={["Favorites", "Want to Try", "All Cafes"]}
        selected={selectedSection}
        ariaLabel="Cafe section"
        onSelect={(label) => {
          if (label === "Favorites") onNavigate?.("CF-01");
          if (label === "Want to Try") onNavigate?.("CF-02");
          if (label === "All Cafes") onNavigate?.("CF-03");
        }}
        className="mg-section-tabs"
      />
      <div className="mg-search-row">
        <SearchField value={query} focused={focused} interactive={interactive} onFocus={() => onNavigate?.("search")} />
        <button className="mg-square-control" data-active={filterCount > 0 ? "true" : "false"} aria-label={`Filters, ${filterCount} applied`} onClick={() => onNavigate?.("filters")}>
          <Filter size={19} />
          {filterCount > 0 ? <span className="mg-control-badge">{filterCount}</span> : null}
        </button>
      </div>
      {status}
      <div className="mg-browse-toolbar">
        <button className="mg-sort-control" onClick={() => onNavigate?.("sort")}>
          <ArrowDownUp size={16} /> Recent activity
          <ChevronDown size={14} />
        </button>
        <span className="mg-result-count">{resultCount} {resultCount === 1 ? "cafe" : "cafes"}</span>
        <button className="mg-density-control" aria-label="Cafe card density">
          <ListFilter size={16} /> {density === "compact" ? "Compact" : "Cards"} <ChevronDown size={14} />
        </button>
      </div>
      {density === "compact" ? <span className="mg-density-note"><List size={14} /> Compact density</span> : null}
    </header>
  );
}

function BottomDock({ selected = "Saved", onNavigate }: { selected?: "Map" | "Feed" | "Saved" | "Journal"; onNavigate?: (target: NavigateTarget) => void }) {
  const items = [
    { label: "Map", icon: Map },
    { label: "Feed", icon: Sparkles },
    { label: "Add", icon: CirclePlus },
    { label: "Saved", icon: Bookmark },
    { label: "Journal", icon: NotebookPen },
  ];

  return (
    <nav className="mg-bottom-dock" aria-label="App tabs">
      {items.map(({ label, icon: Icon }) => (
        <button
          key={label}
          data-selected={selected === label ? "true" : "false"}
          aria-current={selected === label ? "page" : undefined}
          onClick={() => {
            if (label === "Map") onNavigate?.("map");
            if (label === "Saved") onNavigate?.("list");
          }}
        >
          <Icon size={22} fill={label === "Saved" && selected === label ? "currentColor" : "none"} />
          <span>{label}</span>
        </button>
      ))}
    </nav>
  );
}

function StatusBanner({ kind, children, action }: { kind: "updating" | "offline" | "stale" | "error"; children: React.ReactNode; action?: string }) {
  const icon = kind === "updating" ? <RefreshCw className="mg-spin-slow" size={16} /> : kind === "offline" ? <WifiOff size={16} /> : kind === "stale" ? <Clock3 size={16} /> : <AlertTriangle size={16} />;
  return (
    <div className="mg-status-banner" data-kind={kind} role="status">
      {icon}
      <span>{children}</span>
      {action ? <button>{action}</button> : null}
    </div>
  );
}

function Snackbar({ kind = "success", message, action = "Undo" }: { kind?: "success" | "error"; message: string; action?: string }) {
  return (
    <div className="mg-snackbar" data-kind={kind} role="status">
      {kind === "success" ? <Check size={18} /> : <CircleAlert size={18} />}
      <span>{message}</span>
      <button>{action}</button>
    </div>
  );
}

function SkeletonCards() {
  return (
    <div className="mg-card-stack" aria-label="Loading saved cafes">
      {[0, 1, 2].map((index) => (
        <div className="mg-skeleton-card" key={index}>
          <span className="mg-skeleton mg-skeleton-image" />
          <span className="mg-skeleton-copy">
            <span className="mg-skeleton mg-skeleton-name" />
            <span className="mg-skeleton mg-skeleton-line" />
            <span className="mg-skeleton mg-skeleton-short" />
          </span>
          <span className="mg-skeleton mg-skeleton-button" />
        </div>
      ))}
    </div>
  );
}

function EmptyState({ kind, retrying = false }: { kind: "favorites" | "wantToTry" | "all" | "search" | "filtered" | "fatal"; retrying?: boolean }) {
  const copy = {
    favorites: { image: "/assets/mugshot/mugsy-favorites.png", title: "No favorites yet", body: "Tap the heart on a cafe you love and it will appear here.", cta: "Browse the Map" },
    wantToTry: { image: "/assets/mugshot/mugsy-wishlist.png", title: "Nothing on your try list", body: "Save cafes you want to visit next.", cta: "Find cafes" },
    all: { image: "/assets/mugshot/mugsy-cafes.png", title: "Your cafe library is empty", body: "Log a Sip or save a cafe to start your personal library.", cta: "Log a Sip" },
    search: { image: "/assets/mugshot/mugsy-cafes.png", title: "No cafes match “No Such Cafe”", body: "Try another cafe, neighborhood, or drink name.", cta: "Clear Search" },
    filtered: { image: "/assets/mugshot/mugsy-cafes.png", title: "No cafes match these filters", body: "Try changing distance, availability, or personal score.", cta: "Reset Filters" },
    fatal: { image: "/assets/mugshot/mugsy-cafes.png", title: "Saved cafes couldn’t load", body: "Check your connection and try again.", cta: "Retry" },
  }[kind];

  return (
    <section className="mg-empty-state">
      <img src={copy.image} alt="Mugsy" />
      <h2>{copy.title}</h2>
      <p>{copy.body}</p>
      <button className="mg-primary-button" disabled={retrying}>
        {retrying ? <LoaderCircle className="mg-spin" size={18} /> : kind === "fatal" ? <RefreshCw size={18} /> : <Map size={18} />}
        {retrying ? "Trying again…" : copy.cta}
      </button>
      {kind === "all" ? <button className="mg-secondary-button">Explore cafes</button> : null}
    </section>
  );
}

function ListScreen({ id, interactive, onNavigate }: PhoneScreenProps) {
  const section = id === "CF-02" || id === "RS-08" ? "wantToTry" : id === "CF-03" || id === "CF-04" || id === "CF-06" || id === "CF-07" || id === "CF-09" || id === "CF-10" || id === "RS-09" || id === "RS-10" ? "all" : "favorites";
  const compact = id === "CF-04" || id === "CF-06";
  const query = id === "CF-05" ? "harbor" : id === "CF-06" ? "moon" : id === "CF-07" ? "No Such Cafe" : "";
  const filterCount = id === "CF-09" || id === "RS-10" ? 2 : 0;
  const isAccessibility = id === "AX-01";
  const isContrast = id === "AX-04";
  const isLoading = id === "RS-01";
  const isEmpty = ["CF-07", "RS-05", "RS-06", "RS-07", "RS-08", "RS-09", "RS-10"].includes(id);
  const syncing = id === "ST-01";
  const failed = id === "ST-05";
  let list: CafeFixture[] = section === "favorites" ? favoriteCafeOrder : section === "wantToTry" ? wantToTryCafeOrder.slice(0, 2) : allCafeOrder;

  if (id === "CF-05") list = [cafes.harborlight];
  if (id === "CF-06") list = [cafes.paperMoon];
  if (id === "CF-09") list = [cafes.harborlight, cafes.paperMoon, cafes.archive, cafes.sunward];
  if (id === "ST-03") list = [cafes.archive, cafes.paperMoon, cafes.sunward];
  if (id === "ST-01" || id === "ST-02") list = [cafes.juniper, cafes.cedarRoom];
  if (isAccessibility) list = [cafes.harborlight, cafes.archive];

  let status: React.ReactNode = null;
  if (id === "RS-02") status = <StatusBanner kind="updating">Updating your cafes…</StatusBanner>;
  if (id === "RS-03") status = <StatusBanner kind="offline" action="Retry">Offline · Updated Aug 3 at 9:42 PM</StatusBanner>;
  if (id === "RS-04") status = <StatusBanner kind="stale" action="Refresh">Updated Aug 3 at 6:15 PM</StatusBanner>;

  const emptyKind = id === "CF-07" ? "search" : id === "RS-05" || id === "RS-06" ? "fatal" : id === "RS-07" ? "favorites" : id === "RS-08" ? "wantToTry" : id === "RS-09" ? "all" : "filtered";

  return (
    <div className={`mg-phone-screen mg-list-screen ${isAccessibility ? "mg-accessibility-xxxl" : ""} ${isContrast ? "mg-increase-contrast" : ""}`} data-screen-id={id}>
      <ArtifactStatusBar />
      <div className="mg-list-scroll">
        <SavedHeader
          section={section}
          query={query}
          focused={id === "CF-05"}
          interactive={interactive}
          filterCount={filterCount}
          density={compact ? "compact" : "comfortable"}
          resultCount={isEmpty || isLoading ? 0 : list.length}
          status={status}
          onNavigate={onNavigate}
        />
        {filterCount > 0 ? (
          <div className="mg-filter-chip-row">
            <button>Visited <X size={13} /></button>
            <button>4.0+ <X size={13} /></button>
          </div>
        ) : null}
        {isLoading ? <SkeletonCards /> : isEmpty ? <EmptyState kind={emptyKind} retrying={id === "RS-06"} /> : (
          <div className="mg-card-stack">
            {list.map((cafe, index) => (
              <CafeCard
                key={cafe.id}
                cafe={cafe}
                compact={compact}
                accessibility={isAccessibility}
                syncing={syncing && index === 0}
                failed={failed && index === 0}
                favoriteOverride={id === "ST-01" || id === "ST-02" ? index === 0 : id === "ST-04" && index === 0 ? true : undefined}
                onOpen={() => onNavigate?.("detail")}
                onFavorite={() => onNavigate?.("ST-02")}
              />
            ))}
          </div>
        )}
      </div>
      <BottomDock onNavigate={onNavigate} />
      {id === "ST-02" ? <Snackbar message="Added to Favorites" /> : null}
      {id === "ST-03" ? <Snackbar message="Removed from Favorites" /> : null}
      {id === "ST-04" ? <Snackbar message="Favorite restored" action="Dismiss" /> : null}
      {id === "ST-05" ? <Snackbar kind="error" message="Favorite wasn’t saved" action="Retry" /> : null}
      {id === "CF-05" ? <img className="mg-static-keyboard" src="/assets/iphone/Keyboard.png" alt="iOS keyboard" /> : null}
    </div>
  );
}

function FiltersSheet({ id, onNavigate }: { id: ScreenId; onNavigate?: (target: NavigateTarget) => void }) {
  const accessibility = id === "AX-03";
  return (
    <div className={`mg-phone-screen mg-overlay-screen ${accessibility ? "mg-accessibility-xxxl" : ""}`} data-screen-id={id}>
      <ArtifactStatusBar />
      <div className="mg-overlay-backdrop">
        <SavedHeader section="all" resultCount={8} onNavigate={onNavigate} />
        <div className="mg-overlay-cards"><CafeCard cafe={cafes.harborlight} /></div>
      </div>
      <section className="mg-native-sheet mg-filter-sheet" aria-label="Filters">
        <span className="mg-sheet-grabber" />
        <header><h2>Filters</h2><button>Reset</button></header>
        <div className="mg-filter-section">
          <h3>Visit history</h3>
          <Segmented labels={["Any", "Visited", "Not visited"]} selected="Visited" ariaLabel="Visit history filter" />
        </div>
        <div className="mg-filter-section">
          <h3>Availability</h3>
          <button className="mg-selection-row" data-selected="true"><span><Clock3 size={18} /> Open now</span><Check size={18} /></button>
        </div>
        <div className="mg-filter-section">
          <h3>Personal score</h3>
          <Segmented labels={["Any score", "4.0 and up", "Not rated"]} selected="4.0 and up" ariaLabel="Personal score filter" />
        </div>
        <div className="mg-filter-section">
          <h3>Distance</h3>
          <div className="mg-choice-list">
            {["Any distance", "Within 1 mi", "Within 5 mi", "Within 10 mi"].map((label) => <button key={label} data-selected={label === "Within 5 mi" ? "true" : "false"}>{label}{label === "Within 5 mi" ? <Check size={17} /> : null}</button>)}
          </div>
        </div>
        <button className="mg-primary-button mg-sticky-sheet-button" onClick={() => onNavigate?.("CF-09")}>Show 4 cafes</button>
      </section>
    </div>
  );
}

function SortSheet() {
  return (
    <div className="mg-phone-screen mg-overlay-screen" data-screen-id="CF-10">
      <ArtifactStatusBar />
      <div className="mg-overlay-backdrop"><SavedHeader section="all" resultCount={8} /></div>
      <section className="mg-native-sheet mg-sort-sheet" aria-label="Sort Cafes">
        <span className="mg-sheet-grabber" />
        <h2>Sort Cafes</h2>
        {[
          ["Recent activity", History],
          ["Nearest", LocateFixed],
          ["Highest personal score", Star],
          ["Name", ArrowDownUp],
        ].map(([label, Icon]) => (
          <button key={String(label)} data-selected={label === "Recent activity" ? "true" : "false"}>
            {typeof Icon !== "string" ? <Icon size={20} /> : null}<span>{String(label)}</span>{label === "Recent activity" ? <Check size={19} /> : null}
          </button>
        ))}
      </section>
    </div>
  );
}

function MapSurface({ selected = false, discovery = false, accessibility = false, onNavigate }: { selected?: boolean; discovery?: boolean; accessibility?: boolean; onNavigate?: (target: NavigateTarget) => void }) {
  return (
    <div className={`mg-map-surface ${accessibility ? "mg-map-accessibility" : ""}`}>
      <div className="mg-map-background" aria-label="Map of San Francisco with saved cafe pins" />
      <div className="mg-map-search-row">
        <SearchField placeholder={discovery ? "Search cafes and places" : "Search saved cafes"} />
        <button className="mg-map-filter-pill" aria-label="Map scope, All">
          {discovery ? <Sparkles size={17} /> : <Layers3 size={17} />}
          {discovery ? "Discovery" : "All"}
          <ChevronDown size={14} />
        </button>
        <button className="mg-map-list-button" onClick={() => onNavigate?.("CF-11")}><List size={18} /> List</button>
      </div>
      {!selected ? (
        <>
          <button className="mg-map-location" aria-label="Current location"><Navigation size={20} fill="currentColor" /></button>
          <button className="mg-map-legend"><Star size={16} /> Ratings</button>
        </>
      ) : null}
      {discovery ? <span className="mg-boundary-label"><Map size={15} /> Discovery Map · outside your library</span> : null}
    </div>
  );
}

function DetailIdentity({ cafe, expanded = false, missingPhoto = false }: { cafe: CafeFixture; expanded?: boolean; missingPhoto?: boolean }) {
  return (
    <div className={`mg-detail-identity ${expanded ? "mg-detail-identity-expanded" : ""}`}>
      {!expanded ? <CafeImage cafe={missingPhoto ? { ...cafe, photoState: "missing", image: undefined } : cafe} /> : null}
      <div className="mg-detail-title-copy">
        <h1>{cafe.name}</h1>
        <p>
          {cafe.neighborhood ?? "Location unavailable"}
          {cafe.availability ? <> · <strong>{cafe.availability}</strong></> : null}
          {cafe.distance ? ` · ${cafe.distance}` : ""}
        </p>
        {expanded && cafe.address ? <span>{cafe.address}</span> : null}
      </div>
    </div>
  );
}

function DetailActionGrid({ cafe, wantToTryOverride, accessibility = false }: { cafe: CafeFixture; wantToTryOverride?: boolean; accessibility?: boolean }) {
  const wantToTry = wantToTryOverride ?? cafe.memberships.includes("wantToTry");
  const favorite = cafe.memberships.includes("favorite");
  const actions = [
    { label: favorite ? "Favorited" : "Favorite", icon: Heart, selected: favorite, note: "" },
    { label: "Want to Try", icon: Bookmark, selected: wantToTry, note: "" },
    { label: "Lists", icon: Layers3, selected: (cafe.listCount ?? 0) > 0, note: cafe.listCount ? String(cafe.listCount) : "" },
    { label: "Directions", icon: Navigation, selected: false, disabled: cafe.directionsAvailable === false, note: cafe.directionsAvailable === false ? "Unavailable" : "" },
  ];

  return (
    <div className={`mg-detail-actions ${accessibility ? "mg-actions-accessibility" : ""}`}>
      {actions.map(({ label, icon: Icon, selected, disabled, note }) => (
        <button key={label} data-selected={selected ? "true" : "false"} disabled={disabled} aria-pressed={label === "Directions" ? undefined : selected}>
          <Icon size={23} fill={selected ? "currentColor" : "none"} />
          <span>{label}</span>
          {note ? <small>{note}</small> : null}
        </button>
      ))}
    </div>
  );
}

function YourMugshot({ cafe = cafes.harborlight, empty = false, accessibility = false }: { cafe?: CafeFixture; empty?: boolean; accessibility?: boolean }) {
  if (empty) {
    return (
      <section className="mg-your-mugshot mg-your-mugshot-empty">
        <div className="mg-section-title"><span><UserRound size={18} /> Your Mugshot</span></div>
        <h3>No sips here yet</h3>
        <p>Log your first sip to start a personal history with this cafe.</p>
      </section>
    );
  }

  return (
    <section className={`mg-your-mugshot ${accessibility ? "mg-your-mugshot-accessibility" : ""}`}>
      <div className="mg-section-title"><span><UserRound size={18} /> Your Mugshot</span><button>View history <ChevronRight size={15} /></button></div>
      <p className="mg-insight">Bright drinks and quiet corners keep bringing you back.</p>
      <div className="mg-personal-stats">
        <div><strong>{cafe.personalScore?.toFixed(1) ?? "—"}</strong><span>Personal sip average</span></div>
        <div><strong>{cafe.cafeReflection?.toFixed(1) ?? "—"}</strong><span>Cafe reflection</span></div>
      </div>
      <p className="mg-personal-facts">{cafe.sipCount} sips · Last sip {cafe.lastSip ?? "—"} · Would return</p>
      <p className="mg-favorite-drink"><Coffee size={16} /> Honey oat cortado · ordered twice</p>
    </section>
  );
}

function DetailSheet({
  cafe = cafes.harborlight,
  detent = "medium",
  accessibility = false,
  status,
  wantToTryOverride,
  onNavigate,
}: {
  cafe?: CafeFixture;
  detent?: "compact" | "medium";
  accessibility?: boolean;
  status?: React.ReactNode;
  wantToTryOverride?: boolean;
  onNavigate?: (target: NavigateTarget) => void;
}) {
  return (
    <section className={`mg-native-sheet mg-detail-sheet mg-detail-${detent} ${accessibility ? "mg-detail-sheet-accessibility" : ""}`} aria-label={`${cafe.name} details`}>
      <span className="mg-sheet-grabber" />
      <button className="mg-sheet-close" aria-label="Close cafe details" onClick={() => onNavigate?.("close")}><X size={18} /></button>
      {status}
      <DetailIdentity cafe={cafe} />
      <button className="mg-log-a-sip"><CirclePlus size={21} /> Log a Sip</button>
      {detent === "medium" || accessibility ? <DetailActionGrid cafe={cafe} wantToTryOverride={wantToTryOverride} accessibility={accessibility} /> : null}
      {detent === "medium" || accessibility ? <YourMugshot cafe={cafe} empty={cafe.sipCount === 0} accessibility={accessibility} /> : null}
      {detent === "compact" ? <button className="mg-expand-detail" onClick={() => onNavigate?.("expand")}>More details <ChevronDown size={16} /></button> : null}
    </section>
  );
}

function MapScreen({ id, onNavigate }: PhoneScreenProps) {
  const selected = id === "CF-12" || id === "CF-13";
  const discovery = id === "CF-13";
  const accessibility = false;
  const cafe = discovery ? { ...cafes.juniper, name: "Northline Coffee", neighborhood: "Embarcadero", distance: "0.9 mi", memberships: [] } : cafes.harborlight;
  return (
    <div className={`mg-phone-screen mg-map-screen ${accessibility ? "mg-accessibility-xxxl" : ""}`} data-screen-id={id}>
      <ArtifactStatusBar />
      <MapSurface selected={selected} discovery={discovery} accessibility={accessibility} onNavigate={onNavigate} />
      {selected ? (
        <DetailSheet
          cafe={cafe}
          detent={accessibility ? "medium" : "compact"}
          accessibility={accessibility}
          onNavigate={(target) => onNavigate?.(target === "close" ? "CF-11" : target)}
        />
      ) : <BottomDock selected="Map" onNavigate={onNavigate} />}
    </div>
  );
}

function ExpandedTop({ cafe, missingPhoto = false, unavailable = false, accessibility = false }: { cafe: CafeFixture; missingPhoto?: boolean; unavailable?: boolean; accessibility?: boolean }) {
  return (
    <>
      {!accessibility ? (
        missingPhoto ? (
          <div className="mg-hero-fallback">
            <img src="/assets/mugshot/mugsy-cafes.png" alt="Mugsy" />
            <span><strong>No cafe photo yet</strong><small>The first authorized Mugshot photo can become this cafe’s cover.</small></span>
          </div>
        ) : <figure className="mg-detail-hero"><img src={cafe.image} alt={`${cafe.name} interior`} /><figcaption>{cafe.imageProvenance}</figcaption></figure>
      ) : null}
      <DetailIdentity cafe={cafe} expanded missingPhoto={missingPhoto} />
      {unavailable ? <StatusBanner kind="error">This cafe is temporarily unavailable. Last-known details are shown.</StatusBanner> : null}
      <button className="mg-log-a-sip" disabled={unavailable}><CirclePlus size={21} /> Log a Sip</button>
      <DetailActionGrid cafe={cafe} accessibility={accessibility} />
    </>
  );
}

function DetailExpandedScreen({ id }: { id: ScreenId }) {
  const accessibility = id === "AX-02";
  const cafe = id === "CD-08" ? cafes.cedarRoom : id === "CD-09" ? { ...cafes.sunward, unavailable: true } : cafes.harborlight;
  const missingPhoto = id === "CD-08";
  const personal = id === "CD-04";
  const sips = id === "CD-05";
  const social = id === "CD-06";
  const partial = id === "RS-12";
  const expandedTop = id === "CD-03" || id === "CD-08" || id === "CD-09" || accessibility;

  return (
    <div className={`mg-phone-screen mg-expanded-detail-screen ${accessibility ? "mg-accessibility-xxxl" : ""}`} data-screen-id={id}>
      <ArtifactStatusBar />
      <div className="mg-expanded-nav"><button aria-label="Back"><ArrowLeft size={20} /></button><span>Cafe details</span><button aria-label="More"><MoreHorizontal size={21} /></button></div>
      <div className="mg-expanded-scroll">
        {expandedTop ? <ExpandedTop cafe={cafe} missingPhoto={missingPhoto} unavailable={id === "CD-09"} accessibility={accessibility} /> : (
          <div className="mg-collapsed-detail-header"><CafeImage cafe={cafes.harborlight} /><span><strong>Harborlight Coffee Roasters</strong><small>Embarcadero · 0.8 mi</small></span><button><CirclePlus size={17} /> Log</button></div>
        )}
        {personal || accessibility ? (
          <>
            <YourMugshot cafe={cafes.harborlight} accessibility={accessibility} />
            <section className="mg-private-note"><LockKeyhole size={18} /><div><strong>Private note</strong><p>Window seats are quiet before 9 AM.</p></div><button>Edit</button></section>
            <section className="mg-favorite-drinks"><div className="mg-section-title"><span>Favorite drinks</span></div><div><span>Honey oat cortado</span><small>2 sips</small></div><div><span>Espresso tonic</span><small>1 sip</small></div></section>
          </>
        ) : null}
        {sips ? (
          <section className="mg-recent-sips">
            <div className="mg-section-title"><span>Recent sips</span><button>See all 4 <ChevronRight size={15} /></button></div>
            {recentSips.map((sip) => (
              <article key={sip.drink}><img src={sip.image} alt={sip.drink} /><div><strong>{sip.drink}</strong><span>{sip.date} · {sip.visibility}</span><p>{sip.caption}</p></div><b>{sip.score}</b></article>
            ))}
          </section>
        ) : null}
        {social || partial ? (
          <>
            <section className="mg-attributed-section">
              <div className="mg-section-title"><span>Friends on Mugshot</span><small>2 visible sips</small></div>
              {partial ? <StatusBanner kind="error" action="Retry">Some friend activity couldn’t refresh</StatusBanner> : socialActivity.map((activity) => (
                <article key={activity.name}><div className="mg-avatar"><UserRound size={18} /></div><div><strong>{activity.name}</strong><span>{activity.drink} · {activity.score}</span><small>{activity.visibility} · {activity.date}</small></div><ChevronRight size={17} /></article>
              ))}
            </section>
            <section className="mg-attributed-section">
              <div className="mg-section-title"><span>Mugshot community</span><small>Public only</small></div>
              <p>Calm for work · Warm service</p>
              <small>Based on 18 public Cafe Pulse check-ins from 12 people · Updated 3d ago</small>
            </section>
            <section className="mg-cafe-pulse"><Sparkles size={20} /><div><strong>Cafe Pulse</strong><p>Regulars remember the calm room and milk drinks most.</p><small>Evidence threshold met · Updated Aug 3</small></div></section>
          </>
        ) : null}
        {expandedTop && !accessibility ? <YourMugshot cafe={cafe} empty={cafe.sipCount === 0} /> : null}
        <section className="mg-more-detail"><button><ExternalLink size={18} /> Website</button><button><Share2 size={18} /> Share cafe</button><button><Copy size={18} /> Copy address</button><button><CircleAlert size={18} /> Report cafe information</button></section>
      </div>
    </div>
  );
}

function MediumDetailScreen({ id, onNavigate }: PhoneScreenProps) {
  const cafe = id === "CD-07" ? cafes.juniper : id === "ST-06" ? cafes.paperMoon : cafes.harborlight;
  const offline = id === "CD-13";
  const wantToTryOverride = id === "ST-06" ? false : undefined;
  return (
    <div className="mg-phone-screen mg-map-screen" data-screen-id={id}>
      <ArtifactStatusBar />
      <MapSurface selected onNavigate={onNavigate} />
      <DetailSheet
        cafe={cafe}
        detent="medium"
        wantToTryOverride={wantToTryOverride}
        status={offline ? <StatusBanner kind="offline" action="Retry">Offline · Updated Aug 3 at 9:42 PM</StatusBanner> : undefined}
        onNavigate={onNavigate}
      />
      {id === "ST-06" ? (
        <div className="mg-wtt-celebration" role="status">
          <img src="/assets/mugshot/mugsy-wishlist.png" alt="Mugsy celebrating" />
          <span><strong>You tried it!</strong><small>Removed from Want to Try</small></span>
          <button>Undo</button>
        </div>
      ) : null}
    </div>
  );
}

function SecondaryActionsSheet() {
  return (
    <div className="mg-phone-screen mg-overlay-screen" data-screen-id="CD-10">
      <ArtifactStatusBar />
      <div className="mg-detail-underlay"><ExpandedTop cafe={cafes.harborlight} /></div>
      <section className="mg-native-sheet mg-action-sheet"><span className="mg-sheet-grabber" /><h2>More for Harborlight</h2>
        <button><ExternalLink size={21} /><span><strong>Website</strong><small>Open in browser</small></span><ChevronRight size={18} /></button>
        <button><Share2 size={21} /><span><strong>Share Cafe</strong><small>Send a place link</small></span><ChevronRight size={18} /></button>
        <button><Copy size={21} /><span><strong>Copy Address</strong><small>12 Embarcadero Center</small></span><ChevronRight size={18} /></button>
        <button><CircleAlert size={21} /><span><strong>Report cafe information</strong><small>Hours, location, or availability</small></span><ChevronRight size={18} /></button>
      </section>
    </div>
  );
}

function MembershipSheet({ failed = false }: { failed?: boolean }) {
  const rows = [
    { name: "Weekend Walks", note: "Private · 4 cafes", selected: true, role: "Owner" },
    { name: "SF Standouts", note: "Shared with Amanda · 7 cafes", selected: true, role: "Collaborator", failed },
    { name: "Date Ideas", note: "Private · 3 cafes", selected: false, role: "Owner" },
    { name: "Quiet Corners", note: "Shared · 12 cafes", selected: false, role: "View only", disabled: true },
  ];
  return (
    <div className="mg-phone-screen mg-overlay-screen" data-screen-id={failed ? "CD-12" : "CD-11"}>
      <ArtifactStatusBar />
      <div className="mg-detail-underlay"><ExpandedTop cafe={cafes.harborlight} /></div>
      <section className="mg-native-sheet mg-membership-sheet"><span className="mg-sheet-grabber" />
        <header><button>Cancel</button><h2>Add to Lists</h2><button>Done</button></header>
        {failed ? <StatusBanner kind="error" action="Retry">Couldn’t update 1 list · Other changes were saved</StatusBanner> : null}
        <div className="mg-membership-rows">
          {rows.map((row) => <button key={row.name} disabled={row.disabled} data-selected={row.selected ? "true" : "false"} data-failed={row.failed ? "true" : "false"}>
            <span className="mg-list-icon"><Layers3 size={20} /></span><span><strong>{row.name}</strong><small>{row.note} · {row.role}</small>{row.failed ? <em>Couldn’t update · Retry</em> : null}</span><span className="mg-check-control">{row.selected ? <Check size={19} /> : null}</span>
          </button>)}
        </div>
        <p className="mg-protected-scope"><LockKeyhole size={15} /> List creation and collaboration stay unchanged.</p>
        <button className="mg-primary-button">Save to 2 lists</button>
      </section>
    </div>
  );
}

function GuestGate() {
  return (
    <div className="mg-phone-screen mg-overlay-screen" data-screen-id="RS-06">
      <ArtifactStatusBar />
      <div className="mg-overlay-backdrop"><SavedHeader section="favorites" resultCount={0} /></div>
      <section className="mg-native-sheet mg-guest-sheet"><span className="mg-sheet-grabber" /><img src="/assets/mugshot/mugsy-cafes.png" alt="Mugsy" /><h2>Keep this cafe with you</h2><p>Sign in to Log a Sip at Harborlight Coffee Roasters. Your cafe and action will be ready when you return.</p><button className="mg-primary-button"><UserRound size={18} /> Sign In</button><button className="mg-secondary-button">Not now</button><small><LockKeyhole size={13} /> No cafe or location data is sent until you continue.</small></section>
    </div>
  );
}

function DetailLoadingScreen() {
  return (
    <div className="mg-phone-screen mg-expanded-detail-screen" data-screen-id="RS-11">
      <ArtifactStatusBar />
      <div className="mg-expanded-nav"><button aria-label="Close"><X size={20} /></button><span>Cafe details</span><span /></div>
      <div className="mg-detail-loading" aria-label="Loading cafe details">
        <span className="mg-skeleton mg-detail-skeleton-hero" />
        <span className="mg-skeleton mg-detail-skeleton-title" />
        <span className="mg-skeleton mg-detail-skeleton-line" />
        <span className="mg-skeleton mg-detail-skeleton-button" />
        <div className="mg-detail-skeleton-actions">{[0, 1, 2, 3].map((i) => <span className="mg-skeleton" key={i} />)}</div>
        <span className="mg-skeleton mg-detail-skeleton-section" />
      </div>
    </div>
  );
}

export function PhoneScreen({ id, interactive = false, onNavigate }: PhoneScreenProps) {
  if (id === "CF-08" || id === "AX-03") return <FiltersSheet id={id} onNavigate={onNavigate} />;
  if (id === "CF-10") return <SortSheet />;
  if (["CF-11", "CF-12", "CF-13"].includes(id)) return <MapScreen id={id} interactive={interactive} onNavigate={onNavigate} />;
  if (["CD-02", "CD-07", "CD-13", "ST-06"].includes(id)) return <MediumDetailScreen id={id} interactive={interactive} onNavigate={onNavigate} />;
  if (["CD-03", "CD-04", "CD-05", "CD-06", "CD-08", "CD-09", "RS-12", "AX-02"].includes(id)) return <DetailExpandedScreen id={id} />;
  if (id === "CD-10") return <SecondaryActionsSheet />;
  if (id === "CD-11") return <MembershipSheet />;
  if (id === "CD-12") return <MembershipSheet failed />;
  if (id === "RS-06") return <GuestGate />;
  if (id === "RS-11") return <DetailLoadingScreen />;
  return <ListScreen id={id} interactive={interactive} onNavigate={onNavigate} />;
}

export function InteractiveSavedPrototype() {
  const initialId = useMemo(() => {
    const candidate = new URLSearchParams(window.location.search).get("frame") as ScreenId | null;
    return candidate ?? "CF-01";
  }, []);
  const [screenId, setScreenId] = useState<ScreenId>(initialId);
  const [returnScreenId, setReturnScreenId] = useState<ScreenId>(initialId.startsWith("CF-") ? initialId : "CF-01");

  const navigate = (target: NavigateTarget) => {
    if (target.startsWith("CF-") || target.startsWith("CD-") || target.startsWith("ST-") || target.startsWith("RS-") || target.startsWith("AX-")) {
      if (["CF-01", "CF-02", "CF-03", "CF-04", "CF-05", "CF-06", "CF-07", "CF-09"].includes(target)) {
        setReturnScreenId(target as ScreenId);
      }
      setScreenId(target as ScreenId);
      return;
    }
    if (target === "filters") setScreenId("CF-08");
    if (target === "sort") setScreenId("CF-10");
    if (target === "search") setScreenId("CF-05");
    if (target === "map") setScreenId("CF-11");
    if (target === "list") setScreenId(returnScreenId.startsWith("CF-") ? returnScreenId : "CF-01");
    if (target === "close") setScreenId(returnScreenId);
    if (target === "detail") {
      setReturnScreenId(screenId);
      setScreenId("CD-02");
    }
    if (target === "expand") setScreenId("CD-03");
  };

  return <PhoneScreen id={screenId} interactive onNavigate={navigate} />;
}
