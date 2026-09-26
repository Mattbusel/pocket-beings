# App Review notes

Pasted into the "Notes" field of the App Review Information section. Also
supplied programmatically by `Store/listing.py review-details`.

---

No account, login or network connection is required. Tap NEW TOWN and the game
starts immediately.

HOW TO PLAY: seven cartoon characters live in a town and act on their own every
couple of seconds (stealing, giving gifts, founding businesses, running for
office, printing money, going to jail). Their actions appear in the newspaper
panel. Tap any character in the yard to open its file and use one of five
actions on it (give coins, rob, jail, crown, exile). Close the app and reopen it
to see a summary of what happened while it was closed.

CONTENT: every character is an original, made-up cartoon. No real person,
company, place, brand or event appears or is referenced. There is no violence,
blood, weaponry or peril: "jail" is a padlock icon and "rob" moves cartoon coins
between characters. There is no gambling for real money; the "all in" event is a
coin flip with the game's own pretend coins and cannot be purchased or cashed
out. No user-generated content, no chat, no web access, no advertising.

AGE RATING: submitted as 4+ (simulated gambling: none, since nothing is wagered
by the player and nothing has value).

PRIVACY: no data of any kind is collected. No analytics, no crash reporting, no
advertising identifier, no server. The town is saved as one JSON file in the
app's own Documents folder on the device.

MONETISATION (1.1): the app is now free. One optional non-consumable in-app
purchase, "The Big Hand" (com.mattbusel.pocketbeings.pro), adds four more
actions (Pardon, Frame, Deputise, Rain 20), a 2 second cooldown instead of 5,
and renaming the town. Everything in 1.0 stays free. To see the paywall: on the
title screen tap the underlined link "The Big Hand: meddle harder"; or in a town
tap any character and tap one of the four locked actions; or tap the locked
RENAME at the bottom of the town window. Restore is the RESTORE button on the
paywall window. People who bought 1.0 are recognised through AppTransaction and
unlocked automatically. No subscription, no advertising.

INFORMATION REQUESTED UNDER GUIDELINE 2.1 (new account):
PURPOSE / AUDIENCE: an offline toy town. Seven original cartoon characters act on their own (steal, gift, found businesses, run for office, print money, go to jail) and the player watches and meddles. Entertainment for casual players of any age; rated 4+.
SETUP: none. Tap NEW TOWN. Everything is reachable from that one screen.
EXTERNAL SERVICES: none. No network requests, no data providers, no auth, no payments, no AI service, no analytics, no crash reporting, no ads, no third-party SDKs. Only SwiftUI, SpriteKit, Foundation and Combine. Behaviour comes from a local deterministic rules engine; the save is one JSON file in the app's Documents folder.
REGIONAL DIFFERENCES: none. Identical in every region.
REGULATED INDUSTRY / PROTECTED MATERIAL: not applicable. All characters, names, art, text and code are original. Coins have no real value and nothing is wagered by the player.
A screen recording showing launch, NEW TOWN, autonomous characters, the newspaper, and the Crown and Jail actions was supplied in the App Review message thread.
