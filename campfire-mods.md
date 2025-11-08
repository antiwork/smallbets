# Major Campfire Modifications

We modified Campfire extensively to serve the needs of the [Small Bets](https://smallbets.com) community. Below are some of the changes that may be interesting to anyone running a customized Campfire instance. Feel free to take any of our changes.


## Mentions tab
Members can see the list of mentions easily from a new view in the sidebar.

<img width="1297" height="841" src="https://github.com/user-attachments/assets/3376e6c4-c16b-4ba6-a957-b61a4bfe2fc4" />

- https://github.com/antiwork/smallbets/compare/f9b7ba3f98a7ea575e115c45bcfdb47cd46e48ae...53d8b1e742935800ee33cdf380e18571634909fa
- https://github.com/antiwork/smallbets/commit/d57db1930272978b36355aff8d28f56f9dfdd389


## Email notifications
Members get an email notification if they have an unread mention or direct message.

<img width="969" height="890" src="https://github.com/user-attachments/assets/d84719a5-e526-4f74-9c9a-58acab1304b9" />

- https://github.com/antiwork/smallbets/compare/b510fecf31d33b4090859049d89d12448d239fcd...9093deddfc3c3272e9a9b2e15aec7d378344f6be


## User counter
Members can see how many other people are in a room.

<img width="1297" height="853" src="https://github.com/user-attachments/assets/e1402300-a2b8-45ed-9794-845bad616ae8" />

- https://github.com/antiwork/smallbets/commit/0a2c8bb92350f4199dd27719029db84cf1d0fcce


## New since last visit
Members can catch up from where they left with a “since last visit” line, similar to Hey’s Feed feature.

<img width="400" src="https://github.com/user-attachments/assets/98e7c931-72bf-4fcd-b942-f50ff9557bcf" />

- https://github.com/antiwork/smallbets/commit/efc8cc83c4ee55c34a95af7db125922109e3367f


## Mark messages as unread
Members can mark a message as unread.

<img width="1297" height="867" src="https://github.com/user-attachments/assets/3fad4894-052e-4401-9236-dea847a6d9bc" />

- https://github.com/antiwork/smallbets/commit/ca728dc1c6e907e588f46fce397ca550e3c2199e


## Email-based auth
Members can log in with their email instead of with a password.

<img width="450" height="841" src="https://github.com/user-attachments/assets/88604e33-2b92-4b5d-8e1c-76d3552b23f2" />
<img width="450" height="841"  src="https://github.com/user-attachments/assets/d67893b3-4833-403a-bf6f-091d362f724b" />


## Bookmarks
Members can bookmark messages, and the bookmarks can be seen from a new view in the sidebar.

<img width="1297" height="841" src="https://github.com/user-attachments/assets/05e5dee1-baff-42b6-a899-1619bf79b6f2" />


- https://github.com/antiwork/smallbets/compare/975eb2f3f2db076e88c6bd4cfcb0d9bc3994c843...02999bd01d9e8de03df8bfef567f44573a16ed77


## One-click reboost
Members can quickly repeat someone else's boost just by clicking on it.

- https://github.com/antiwork/smallbets/commit/bb871e05e5c42b5fde2bf655ba2b39f6111873b4


## Mentions list relevance
As the number of members increased in the thousands, we started having many people with the same first name and it became increasingly harder to find the right person to mention. We addressed this by ranking the mentions list based on the recency of the person's last message.

<img width="621" height="212" src="https://github.com/user-attachments/assets/71f39398-7199-407b-a555-069fd8f93a3f" />

- https://github.com/antiwork/smallbets/commit/56fed986542c8688dfab9b69a6eb8ae775599eb6


## Replies as mentions
We thought replies deserved the mention treatment. i.e. triggering a notification, vibrating pink bubble, and appearing in our new mentions tab.

- https://github.com/antiwork/smallbets/commit/7a3f2c87f1effd926d8841c7eeacd25f92b1ba95


## Maintain scrollbar position in sidebar
When the number of rooms outgrew the sidebar height, switching between rooms caused the sidebar scroll position to reset to the top. This fix preserves the scroll position, but it still flickers for a brief split second.

- https://github.com/antiwork/smallbets/commit/3cc84c67641fdb1b1014787cca8e2f78b034be0d


## Boost speed
We consolidated two server roundtrips into one, which made boosts feel quite a bit more snappy especially for members far away from our server.

- https://github.com/antiwork/smallbets/commit/9276de6fdfe3d9d79ec15da8ad02cb4d6884c31f


## Hide empty pings from sidebar
We noticed that whenever someone clicks on an avatar from the pings bar, a direct room gets created and that room lingers in the bar forever. This was causing an accumulation of avatars in the pings bar. We mitigated this by not showing empty direct rooms.

- https://github.com/antiwork/smallbets/commit/8ae11bc25e91234888f15739523166c65b268570
- https://github.com/antiwork/smallbets/commit/9d4a67dc5d5962b5ea702f1bc571fbadf71580f7


## Updated names cache
When someone changes their name, their old name remained in the message fragments cache. This led to a few times where we couldn't find/mention the author of a recent message in the room. Our change cleans messages from the cache for the user who changes their info.

- https://github.com/antiwork/smallbets/commit/2dd95b03dabaef0513122f74ab5b710018233d82


## Threads
We found a neat implementation where threads are just special rooms with a parent message, and they disappear after 30 days of inactivity.

For us, threads work like message boards in Basecamp, and they've been great at this use case. We let members submit project pitches in Campfire and we have multiple rounds of feedback inside a thread. This lets us have all the correspondence in one place. Otherwise, we don't encourage thread use for general chatter.

<img width="1097" src="https://github.com/user-attachments/assets/10ab3ff0-3817-41fa-9322-f6e575304be0" />

- https://github.com/antiwork/smallbets/commit/7caa8de1da8c5fbc82db0d4f57bca168656bf774
- https://github.com/antiwork/smallbets/compare/ddbc11f0f9fa65692dcd5eb00a87510037fa4a3e...f2e768ead19cd090a0ac0d883c9fe2a735bbdd2d
- https://github.com/antiwork/smallbets/commit/45576812b9cdb5caef387790fe65910230eccb1f
- https://github.com/antiwork/smallbets/compare/7333c40abc545c1900d4e23cfcef0fb557b2290e...9ad6e5d0a57957907a5911a30778212dabfa5e48


## Unread thread indicators
Members can see which threads have unread messages by looking for a bold "Last reply" timestamp. This only shows for threads they participate in (authored parent message, replied, mentioned, or starred the parent room). Users who star a room are automatically added as participants in all threads in that room.

- [`app/models/room.rb`](app/models/room.rb) - `unread_for?(user)` method
- [`app/models/rooms/thread.rb`](app/models/rooms/thread.rb) - Promotion callback
- [`app/models/membership.rb`](app/models/membership.rb) - Starring promotion + broadcasts
- [`app/views/messages/_threads.html.erb`](app/views/messages/_threads.html.erb) - Data attribute
- [`app/assets/stylesheets/application/messages.css`](app/assets/stylesheets/application/messages.css) - Styling


## Block pings
Members can block users from sending them direct messages. Admins can monitor which members are getting blocked.

<img width="1297" height="867" src="https://github.com/user-attachments/assets/01cfc54b-44b0-41e5-90f3-d6fd402b9eb1" />

- https://github.com/antiwork/smallbets/commit/a4687e1bb9ad40871423d88323573e345ba68df4


## Stats page
General stats and various activity leaderboards.

<img width="450" src="https://github.com/user-attachments/assets/6b66acf9-d14d-409c-97b3-c9c976a6c9da" />
<img width="450" src="https://github.com/user-attachments/assets/0ad6e510-416d-4ab4-8fb6-e2dc60c53539" />


## Rich-text messaging from mobile
This change enables rich-text options on mobile.

<img width="400" src="https://github.com/user-attachments/assets/7cd890c8-7180-4fdf-b392-80cfd820c0dc" />

- https://github.com/antiwork/smallbets/commit/d7ef9c9cded2a5eb547c8142707015961f817c5a


## Soft deletion
Moved to soft deletion for accounts, bookmarks, boosts, memberships, messages, and rooms. This prevents destructive actions from untrusted members.

- https://github.com/antiwork/smallbets/commit/cd4fb3c71729e630018a636e94819e1a0ded6ad3
- https://github.com/antiwork/smallbets/commit/bda3f96f7fa9f7ad1cdc82add617851dcf95a26c


## Bot API extras
Each bot offers an additional webhook that receives all message/boost/user events in Campfire, including DMs. This everything webhook has been useful to build an AI chatbot that knows everything that's going on, not just when it's mentioned. We also use the everything webhook for moderation, to check that nobody is spamming in pings or doing other suspicious things.

Bots can also properly mention users with a special notation @{user_id}. And bots can now also initiate a ping with anyone by POSTing to /rooms/<key>/directs with the user_ids in the payload. This is handy for welcome messages when a new person joins Campfire. The everything webhook already sends an event when a new user is created, and the bot can react to that with a ping.

Some API examples here.

- https://github.com/antiwork/smallbets/commit/e5d14880a4f2a81f4b080c3db5b4747bf20675cf
- https://github.com/antiwork/smallbets/commit/59c528b10f7bffc5342d167c4e22b5564fb4f8ee
- https://github.com/antiwork/smallbets/commit/62f159807b410956a03f1817a1417992434910d8

