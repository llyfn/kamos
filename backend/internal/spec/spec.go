// DO NOT EDIT. Generated from specs/invariants.yaml by scripts/gen-spec.py.
// Edit the YAML and re-run the generator; CI fails on drift.

package spec

// SchemaVersion mirrors specs/invariants.yaml schema_version.
const SchemaVersion = 1

// Rating bounds and grid step per SPEC §4.2.
const (
	RatingMin    = 0.5
	RatingMax    = 5.0
	RatingStep   = 0.25
	RatingLevels = 19
)

// Photos per-submission cap per SPEC §4.1.
const PhotosMaxPerSubmission = 1
const PhotosLegacyReadableCap = 4

// Text caps.
const (
	ReviewMaxChars            = 500
	CommentMinChars           = 1
	CommentMaxChars           = 500
	BeverageRequestNotesMax   = 500
	BeverageRequestStringMax  = 200
	BeverageRequestPayloadMax = 4096
	CollectionEntryNoteMax    = 200
	CollectionNameMax         = 50
	DisplayNameMin            = 1
	DisplayNameMax            = 50
	BioMax                    = 200
	PasswordMin               = 8
)

// Username regex per SPEC §3.2.
const UsernameRegex = `^[A-Za-z0-9_]{3,30}$`
const UsernameStorageRegex = `^[a-z0-9_]{3,30}$`
const UsernameMinChars = 3
const UsernameMaxChars = 30

const EmailVerificationLinkTTLHours = 24

// Pagination per SPEC §5.2.
const (
	PageSizeDefault       = 20
	PageSizeMax           = 50
	PageSizeFeed          = 20
	PageSizeNotifications = 20
	PageSizeFoursquare    = 20
)

// Locales per SPEC §8.
var SupportedLocales = []string{"en", "ja", "ko"}

const LocaleDefault = "en"
const LocaleFallback = "en"

const UsernameHoldDays = 30
const NotificationsReadRetentionDays = 180

const CursorSecretMinBytes = 32

// Category slugs per SPEC §2.1.
var CategorySlugs = []string{"nihonshu", "shochu", "liqueur"}

// CategoryNames[slug][locale] -> localized category label.
var CategoryNames = map[string]map[string]string{
	"nihonshu": {"en": "Nihonshu (Sake)", "ja": "日本酒", "ko": "니혼슈 (사케)"},
	"shochu":   {"en": "Shochu", "ja": "焼酎", "ko": "쇼츄"},
	"liqueur":  {"en": "Liqueur", "ja": "リキュール", "ko": "리큐어"},
}

// DefaultCollectionInventory[locale] / DefaultCollectionWishlist[locale].
var DefaultCollectionInventory = map[string]string{"en": "Inventory", "ja": "インベントリー", "ko": "인벤토리"}
var DefaultCollectionWishlist = map[string]string{"en": "Wishlist", "ja": "ウィッシュリスト", "ko": "위시리스트"}

// Controlled vocabularies.
var PurchaseTypes = []string{"on_premise", "retail", "gift", "other"}
var PriceCurrencies = []string{"JPY", "KRW", "USD"}
var PriceModes = []string{"serving", "bottle"}
