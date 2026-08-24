export type CafeMembership = "favorite" | "wantToTry" | "visited";

export type CafeFixture = {
  id: string;
  name: string;
  neighborhood?: string;
  address?: string;
  availability?: string;
  distance?: string;
  memberships: CafeMembership[];
  listCount?: number;
  personalScore?: number;
  cafeReflection?: number;
  sipCount: number;
  lastSip?: string;
  image?: string;
  imageProvenance?: string;
  directionsAvailable?: boolean;
  websiteAvailable?: boolean;
  photoState?: "loaded" | "missing" | "failed";
  unavailable?: boolean;
};

export const fixtureNow = "Tue, Aug 4, 2026 at 10:30 AM";

export const cafes: Record<string, CafeFixture> = {
  harborlight: {
    id: "harborlight",
    name: "Harborlight Coffee Roasters",
    neighborhood: "Embarcadero",
    address: "12 Embarcadero Center, San Francisco, CA",
    availability: "Open until 5:00 PM",
    distance: "0.8 mi",
    memberships: ["favorite", "visited"],
    listCount: 2,
    personalScore: 4.8,
    cafeReflection: 4.6,
    sipCount: 4,
    lastSip: "Aug 1",
    image: "/assets/mugshot/cafe-corner.png",
    imageProvenance: "Photo from your Aug 1 Mugshot · Private",
    directionsAvailable: true,
    websiteAvailable: true,
    photoState: "loaded",
  },
  juniper: {
    id: "juniper",
    name: "Juniper & Stone",
    neighborhood: "Hayes Valley",
    address: "401 Grove Street, San Francisco, CA",
    availability: "Open until 6:00 PM",
    distance: "1.7 mi",
    memberships: ["wantToTry"],
    listCount: 0,
    sipCount: 0,
    directionsAvailable: true,
    websiteAvailable: true,
    photoState: "missing",
  },
  paperMoon: {
    id: "paper-moon",
    name: "Paper Moon Espresso",
    neighborhood: "Mission",
    address: "88 Valencia Street, San Francisco, CA",
    availability: "Closes at 4:00 PM",
    distance: "2.3 mi",
    memberships: ["favorite", "visited"],
    listCount: 1,
    personalScore: 4.2,
    cafeReflection: 4.1,
    sipCount: 2,
    lastSip: "Aug 3",
    image: "/assets/mugshot/creamy-latte.png",
    imageProvenance: "Photo from your Aug 3 Mugshot · Friends",
    directionsAvailable: true,
    websiteAvailable: true,
    photoState: "loaded",
  },
  littlePalm: {
    id: "little-palm",
    name: "Little Palm Cafe",
    neighborhood: "Castro",
    address: "190 Castro Street, San Francisco, CA",
    availability: "Closed",
    distance: "3.0 mi",
    memberships: ["visited"],
    listCount: 0,
    personalScore: 3.7,
    sipCount: 1,
    lastSip: "Jul 25",
    image: "/assets/mugshot/orange-detail.png",
    imageProvenance: "Photo from your Jul 25 Mugshot · Private",
    directionsAvailable: true,
    websiteAvailable: false,
    photoState: "loaded",
  },
  archive: {
    id: "archive",
    name: "The Archive Coffee Bar Inside the Museum of Contemporary Craft",
    neighborhood: "Downtown",
    address: "150 Market Street, Mezzanine Level, San Francisco, California 94105",
    availability: "Hours unavailable",
    distance: "1.1 mi",
    memberships: ["favorite", "visited"],
    listCount: 1,
    personalScore: 4.5,
    sipCount: 3,
    lastSip: "Jul 11",
    directionsAvailable: true,
    websiteAvailable: true,
    photoState: "missing",
  },
  cedarRoom: {
    id: "cedar-room",
    name: "Cedar Room",
    memberships: ["wantToTry"],
    listCount: 1,
    sipCount: 0,
    directionsAvailable: false,
    websiteAvailable: false,
    photoState: "missing",
  },
  sunward: {
    id: "sunward",
    name: "Sunward Cafe",
    neighborhood: "South Beach",
    address: "9 Brannan Street, San Francisco, CA",
    availability: "Open until 3:00 PM",
    distance: "1.4 mi",
    memberships: ["favorite", "visited"],
    listCount: 0,
    personalScore: 3.9,
    sipCount: 1,
    lastSip: "Jun 27",
    directionsAvailable: true,
    websiteAvailable: true,
    photoState: "failed",
  },
  untitled: {
    id: "untitled",
    name: "Untitled Corner",
    memberships: ["favorite"],
    listCount: 0,
    sipCount: 0,
    directionsAvailable: false,
    websiteAvailable: false,
    photoState: "missing",
  },
};

export const allCafeOrder = [
  cafes.harborlight,
  cafes.juniper,
  cafes.paperMoon,
  cafes.littlePalm,
  cafes.archive,
  cafes.cedarRoom,
  cafes.sunward,
  cafes.untitled,
];

export const favoriteCafeOrder = [
  cafes.harborlight,
  cafes.paperMoon,
  cafes.archive,
  cafes.sunward,
  cafes.untitled,
];

export const wantToTryCafeOrder = [cafes.juniper, cafes.cedarRoom, cafes.paperMoon];

export const recentSips = [
  {
    drink: "Honey oat cortado",
    date: "Aug 1",
    score: "4.8",
    visibility: "Private",
    caption: "Bright, balanced, and worth the walk.",
    image: "/assets/mugshot/creamy-latte.png",
  },
  {
    drink: "Matcha",
    date: "Jul 18",
    score: "4.6",
    visibility: "Friends",
    caption: "Silky with a grassy finish.",
    image: "/assets/mugshot/cafe-corner.png",
  },
  {
    drink: "Espresso tonic",
    date: "Jun 20",
    score: "4.9",
    visibility: "Everyone",
    caption: "Crisp citrus and a clean finish.",
    image: "/assets/mugshot/orange-square.png",
  },
];

export const socialActivity = [
  { name: "Amanda", drink: "Iced vanilla latte", score: "4.4", visibility: "Friends", date: "Aug 2" },
  { name: "Marcus", drink: "Espresso", score: "4.1", visibility: "Everyone", date: "Jul 30" },
];

export type ScreenId =
  | `CF-${string}`
  | `CD-${string}`
  | `ST-${string}`
  | `RS-${string}`
  | `AX-${string}`;

export type ScreenDefinition = {
  id: ScreenId;
  slug: string;
  title: string;
  composition: string;
  fixture: string;
  evidence: string;
};

export const screenDefinitions: ScreenDefinition[] = [
  { id: "CF-01", slug: "favorites-populated", title: "Favorites · populated", composition: "saved-list", fixture: "favorites", evidence: "Audit 01, 12–14" },
  { id: "CF-02", slug: "want-to-try-populated", title: "Want to Try · populated", composition: "saved-list", fixture: "wantToTry", evidence: "Audit 02" },
  { id: "CF-03", slug: "all-cafes-union", title: "All Cafes · authoritative union", composition: "saved-list", fixture: "all", evidence: "Audit 03–05" },
  { id: "CF-04", slug: "all-cafes-compact", title: "All Cafes · compact rows", composition: "saved-list-compact", fixture: "all", evidence: "Audit 03–05" },
  { id: "CF-05", slug: "search-focused", title: "Search · keyboard focused", composition: "saved-search", fixture: "query", evidence: "Audit 26" },
  { id: "CF-06", slug: "search-results", title: "Search · results", composition: "saved-list-compact", fixture: "query", evidence: "Audit 26" },
  { id: "CF-07", slug: "search-no-results", title: "Search · no results", composition: "saved-empty", fixture: "query-empty", evidence: "Audit 27" },
  { id: "CF-08", slug: "filters-sheet", title: "Filters · meaningful controls", composition: "filter-sheet", fixture: "filters", evidence: "Audit 06" },
  { id: "CF-09", slug: "filters-applied", title: "Filters · applied", composition: "saved-list", fixture: "filtered", evidence: "Audit 06" },
  { id: "CF-10", slug: "sort-menu", title: "Sort · explicit menu", composition: "sort-sheet", fixture: "sort", evidence: "Audit 03–06" },
  { id: "CF-11", slug: "existing-map-saved-filters", title: "Map tab · existing saved filters", composition: "map-tab", fixture: "map-favorites", evidence: "Audit 24–27" },
  { id: "CF-12", slug: "map-tab-saved-cafe-detail", title: "Map tab · saved cafe detail", composition: "map-tab-detail", fixture: "harborlight", evidence: "Audit 29–31" },
  { id: "CD-02", slug: "detail-medium", title: "Cafe detail · medium", composition: "detail-medium", fixture: "harborlight", evidence: "Audit 07, 29–31" },
  { id: "CD-03", slug: "detail-expanded-top", title: "Cafe detail · expanded top", composition: "detail-expanded", fixture: "harborlight", evidence: "Audit 07" },
  { id: "CD-04", slug: "detail-your-mugshot", title: "Cafe detail · Your Mugshot", composition: "detail-expanded", fixture: "harborlight-personal", evidence: "Audit 08" },
  { id: "CD-05", slug: "detail-recent-sips", title: "Cafe detail · recent sips", composition: "detail-expanded", fixture: "harborlight-sips", evidence: "Audit 08–09" },
  { id: "CD-06", slug: "detail-community-provenance", title: "Cafe detail · attributed activity", composition: "detail-expanded", fixture: "harborlight-social", evidence: "Audit 08–10" },
  { id: "CD-07", slug: "detail-no-history", title: "Cafe detail · no personal history", composition: "detail-medium", fixture: "juniper", evidence: "Audit 07–10" },
  { id: "CD-08", slug: "detail-missing-metadata", title: "Cafe detail · missing metadata", composition: "detail-expanded", fixture: "archive", evidence: "Audit 32–33, 39" },
  { id: "CD-11", slug: "detail-add-to-lists", title: "Add to Lists", composition: "membership-sheet", fixture: "lists", evidence: "Audit 10; Lists protected" },
  { id: "ST-01", slug: "favorite-syncing", title: "Favorite · syncing", composition: "saved-list", fixture: "favorite-syncing", evidence: "Audit 22–23" },
  { id: "ST-02", slug: "favorite-success", title: "Favorite · success with Undo", composition: "saved-list", fixture: "favorite-success", evidence: "Audit 11–13" },
  { id: "ST-03", slug: "unfavorite-active", title: "Unfavorite from Favorites", composition: "saved-list", fixture: "unfavorite", evidence: "Audit 11–13" },
  { id: "ST-04", slug: "unfavorite-undo", title: "Unfavorite · Undo restored", composition: "saved-list", fixture: "unfavorite-undo", evidence: "Audit 11–13" },
  { id: "ST-05", slug: "favorite-failure", title: "Favorite · rollback and Retry", composition: "saved-list", fixture: "favorite-failure", evidence: "Audit 22–23" },
  { id: "ST-06", slug: "first-sip-clears-wtt", title: "First sip · Want to Try celebration", composition: "detail-medium", fixture: "paper-moon-cleared", evidence: "Audit recommendation" },
  { id: "RS-01", slug: "loading-no-cache", title: "Loading · no cache", composition: "saved-loading", fixture: "loading", evidence: "Audit 15" },
  { id: "RS-02", slug: "loading-with-cache", title: "Loading · cached content", composition: "saved-list", fixture: "updating", evidence: "Audit 16" },
  { id: "RS-03", slug: "offline-cached", title: "Offline · cached content", composition: "saved-list", fixture: "offline", evidence: "Audit 17" },
  { id: "RS-04", slug: "stale-online", title: "Stale · refresh available", composition: "saved-list", fixture: "stale", evidence: "Audit 17–18" },
  { id: "RS-05", slug: "fatal-error", title: "Fatal error · no cache", composition: "saved-empty", fixture: "fatal", evidence: "Audit 19" },
  { id: "RS-06", slug: "guest-action-gate", title: "Guest action gate", composition: "guest-sheet", fixture: "guest", evidence: "Audit 34–35" },
  { id: "AX-01", slug: "saved-accessibility-xxxl", title: "Saved · Accessibility XXXL", composition: "saved-list-ax", fixture: "favorites", evidence: "Audit 36" },
  { id: "AX-02", slug: "detail-accessibility-xxxl", title: "Cafe detail · Accessibility XXXL", composition: "detail-ax", fixture: "harborlight", evidence: "Audit 37" },
  { id: "AX-03", slug: "filters-accessibility-xxxl", title: "Filters · Accessibility XXXL", composition: "filter-sheet-ax", fixture: "filters", evidence: "Audit 36–37" },
  { id: "AX-04", slug: "saved-increase-contrast", title: "Saved · Increase Contrast", composition: "saved-list-contrast", fixture: "favorites", evidence: "Audit 38" },
];

export const componentBoards = [
  { id: "CP-01", slug: "navigation-query", title: "Navigation and query controls" },
  { id: "CP-02", slug: "cafe-cards-rows", title: "Cafe cards and compact rows" },
  { id: "CP-03", slug: "map-system", title: "Map pins, clusters, and controls" },
  { id: "CP-04", slug: "detail-system", title: "Cafe detail actions and content" },
  { id: "CP-05", slug: "list-membership", title: "List membership entry states" },
  { id: "CP-06", slug: "feedback-resilience", title: "Feedback and resilience states" },
];

export const specificationBoards = [
  { id: "SP-01", slug: "flow-boundary", title: "Saved and existing Map integration boundary" },
  { id: "SP-02", slug: "frame-inventory", title: "Frame inventory and component reuse" },
  { id: "SP-03", slug: "visual-foundations", title: "Mugshot visual foundations" },
  { id: "SP-04", slug: "component-state-matrix", title: "Component naming and state matrix" },
  { id: "SP-05", slug: "saved-lifecycle", title: "Favorite and Want to Try lifecycle" },
  { id: "SP-06", slug: "accessibility-privacy-boundaries", title: "Accessibility, privacy, media provenance, and protected Lists" },
];
