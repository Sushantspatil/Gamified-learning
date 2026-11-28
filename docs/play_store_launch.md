# Launching SkillVerse on Google Play with payments and ads

The step-by-step runbook. The code is ready: purchases are verified by the backend, rewarded ads are paid only after Google's signed callback, and the Play compliance items (account deletion, privacy policy, subscription terms, ad chest odds, Families-safe ads) are built in.

Backend contract and security model: `../GamifiedQuizApp_digitalHQ/docs/monetization.md`.

> **AdMob, not AdSense.** AdSense is for websites. Ads in an Android app use **AdMob** (admob.google.com), signed in with the same Google account. AdMob has its own Payments page for your earnings.

## 1. Accounts (one-time)

1. **The Google account that will own the app:**
   - Turn on 2-Step Verification and add a recovery phone and email.
   - Teammates get their own access later in Play Console › Users and permissions. Never share this account's password.
2. **Google Play Console** (play.google.com/console/signup): you must be 18 or older. Pay the one-time $25 fee and verify your identity. Choose the account type first:
   - **Personal account:**
     - Your legal name and address come from the payments profile and must match your ID.
     - Google Play shows your legal name, country and email. Because the app sells gems and the Quiz Pass, it also shows **your full address**.
     - You must run a **closed test with at least 12 testers for 14 days in a row** before you can apply for production. Plan for this.
   - **Organization account:**
     - Needs a **D-U-N-S number**. It is free from Dun & Bradstreet but can take up to 30 days.
     - Also needs the organization's website and phone number, and an ID for the person signing up.
     - Google Play shows the organization's name, address, phone, email and D-U-N-S number.
     - The 12-tester rule applies to personal accounts only.
   - **Trader status** (EEA and UK law): every new account declares it at sign-up.
     - Selling in-app items to players in the EEA or UK generally makes you a trader.
     - From 1 March 2027, a personal trader account also shows its phone number.
     - If the app isn't distributed in the EEA or UK, you can declare non-trader.
   - **Verification:**
     - The contact email, contact phone and developer email are each confirmed with a one-time code.
     - Payments profile verification can take up to five days.
3. **Payments profile:** Play Console › Settings › Payments profile. Add the bank account and tax details (PAN/GST in India). You cannot sell in-app products without it.
4. **AdMob:** sign in at admob.google.com with the same Google account and set up Payments (bank and tax details).
5. **Google Cloud project** (console.cloud.google.com), for the purchase-verification service account and Pub/Sub.

## 2. Release signing (once, then keep it safe)

1. Create the upload key and back it up somewhere safe. If it is lost, uploads stop until Google resets it.
   ```bash
   keytool -genkey -v -keystore ~/skillverse-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
   ```
2. Create `android/key.properties`. This file is git-ignored; never commit it.
   ```properties
   storePassword=<password>
   keyPassword=<password>
   keyAlias=upload
   storeFile=/Users/<you>/skillverse-upload.jks
   ```
3. Build the bundle:
   ```bash
   flutter build appbundle --release \
     -PADMOB_APP_ID=ca-app-pub-XXXXXXXXXXXXXXXX~YYYYYYYYYY \
     --dart-define=BASE_URL=https://quiz-api-50046981183.development.catalystappsail.in/api/v1
   ```
   - The AdMob app id comes from step 6.1. Without it the build uses Google's test app id, which serves test ads only.
   - Raise `version:` in `pubspec.yaml` (e.g. `1.0.1+2`) for every upload.
4. Leave **Play App Signing** on when you upload the first bundle. Google keeps the app signing key, and you keep only the upload key.

## 3. Create the app in Play Console

1. **Create app:** set the name, the language, App, Free, and accept the declarations.
2. **Store listing:**
   - Short and full description.
   - Icon 512×512, feature graphic 1024×500, and 2–8 phone screenshots.
   - Category: Education.
   - Contact email and website. The website is needed for `app-ads.txt` in step 6.6.
3. **App content** (Policy › App content):
   - **Privacy policy:** `https://quiz-api-50046981183.development.catalystappsail.in/privacy`. The text is a draft, so have it reviewed and set `SUPPORT_EMAIL` on the backend first.
   - **App access:** "All or some functionality is restricted". Give the reviewers a working test login (email and password).
   - **Ads:** "Yes, my app contains ads".
   - **Advertising ID:** "No". The app removes the `AD_ID` permission and the Privacy Sandbox ad permissions (`ACCESS_ADSERVICES_*`).
   - **Target audience and content:** choose the age groups honestly. If they include **under 13**, the Families policy applies: set `ADS_AGE_TREATMENT=child` on the backend and keep the ad settings in step 6.
   - **Content rating questionnaire:** declare in-app purchases and rewarded ads, and that random rewards (chests, spin wheel) cannot be bought with real money.
   - **Data safety:** collected data:
     - email and name
     - app interactions
     - purchase history
     - app info and performance
     - device or other IDs (collected by the Mobile Ads SDK)

     Encrypted in transit: yes. Users can request deletion: yes.
   - **Account deletion:** `https://quiz-api-50046981183.development.catalystappsail.in/account-deletion`.
   - **Financial features**, **Health**, **Government apps:** "No".
4. **Upload the first bundle to Testing › Internal testing**, and add yourself and your team as testers. Play only lets you create in-app products after a build with billing has been uploaded.

## 4. Payments: products and the Quiz Pass

1. **Monetize › Products › In-app products.** Create these ids exactly; they must match the backend catalog. Set INR prices and activate them.
   - `gems_20` (₹10)
   - `gems_110` (₹49)
   - `gems_240` (₹99)
   - `gems_650` (₹249)
   - `gems_1400` (₹499)

   Prices are suggestions. Topic packs (`pack_…`) come later, together with their content.
2. **Monetize › Products › Subscriptions:** create `quiz_pass` with two auto-renewing base plans, `monthly` (e.g. ₹79) and `yearly` (e.g. ₹699). Activate both.
3. **Let the backend verify purchases:**
   1. In Google Cloud, enable the **Google Play Android Developer API**.
   2. Create a **service account** and download a JSON key.
   3. In Play Console › Users and permissions, invite the service account's email. Grant *View app information*, *View financial data* and *Manage orders and subscriptions*.

   Permissions can take up to a day to start working.
4. **Purchase notifications** (renewals, cancellations, refunds):
   1. In Google Cloud › Pub/Sub, create a topic, e.g. `play-rtdn`.
   2. Give `google-play-developer-notifications@system.gserviceaccount.com` the **Pub/Sub Publisher** role on that topic.
   3. Create a **push** subscription to `https://quiz-api-50046981183.development.catalystappsail.in/api/v1/billing/rtdn?token=<GOOGLE_PLAY_RTDN_TOKEN>`. Tick **Enable authentication**, pick a service account, and set the audience to `https://quiz-api-50046981183.development.catalystappsail.in/api/v1/billing/rtdn`.
   4. In Play Console › Monetize › Monetization setup, enter the topic name, then **Send test notification**.
5. **License testers:** Play Console › Settings › License testing. Add your testers' Gmail accounts; their purchases are free test purchases.

## 5. Backend settings (Catalyst › AppSail › quiz-api › Environment variables)

Generate each secret with `openssl rand -base64 48`. Never put them in `.env` or in git.

| Variable | Value |
|---|---|
| `ENV` | `production` |
| `JWT_SECRET` | **A new private value.** The current one is missing, too short or the public default. Changing it signs everyone out once. |
| `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON_B64` | `base64 -i key.json` of the service-account key |
| `BILLING_ACCOUNT_SECRET` | Random secret. Never change it later: it ties purchases to players. |
| `GOOGLE_PLAY_RTDN_TOKEN` | Random secret, the same value as in the push URL |
| `GOOGLE_PLAY_RTDN_AUDIENCE` | `https://quiz-api-50046981183.development.catalystappsail.in/api/v1/billing/rtdn` |
| `GOOGLE_PLAY_RTDN_PUSH_SA_EMAIL` | The service account the push subscription authenticates as |
| `GOOGLE_PLAY_ALLOW_TEST_PURCHASES` | `true` while testing; `false` at launch |
| `ADS_USER_ID_SECRET` | Random secret |
| `ADMOB_REWARDED_AD_UNIT_ANDROID` | The rewarded ad unit id from step 6.2 |
| `ADS_AGE_TREATMENT` | `teen`, or `child` if the target audience includes under-13s |
| `SUPPORT_EMAIL` | The public contact shown on `/privacy` and `/account-deletion` |

After saving, redeploy the backend (push to `main`, or redeploy in Catalyst). The startup log then says `[Billing] enabled`, and `GET /api/v1/ads/config` shows `rewarded_ads_enabled: true` for a signed-in player.

## 6. Ads (AdMob)

1. **Apps › Add app › Android.** Answer "not published yet" for now, and link it to the Play listing after release. Copy the **App ID** (`ca-app-pub-…~…`) into the build (step 2.3).
2. **Ad units › Rewarded:**
   - Copy the ad unit id (`ca-app-pub-…/…`) into `ADMOB_REWARDED_AD_UNIT_ANDROID`.
   - In the unit's settings, turn on **Server-side verification** with callback URL `https://quiz-api-50046981183.development.catalystappsail.in/api/v1/ads/ssv` and click **Verify**. The server answers Google's test with 200.
   - Reward: amount 1, item "Reward". The server decides the real reward.
3. **Privacy & messaging:** create and publish the GDPR (EEA/UK) message for the app. The app shows it, and an "Ad privacy choices" button, where it is required.
4. **Blocking controls:** set the maximum ad content rating to **G**, and block sensitive categories (gambling, dating, alcohol, politics and similar).
5. **Test devices** (Settings › Test devices): add your phones. Never tap live ads on your own devices; AdMob treats it as invalid traffic.
6. **app-ads.txt:** put the line AdMob shows you, `google.com, pub-XXXXXXXXXXXXXXXX, DIRECT, f08c47fec0942fa0`, at `https://<your website>/app-ads.txt`.
   - The website must be the one in the Play listing, at the root of its domain.
   - The API's Catalyst domain cannot be used for this. Use your own domain, for example a small website or GitHub Pages with a custom domain.
   - Without `app-ads.txt`, ad earnings are limited.

## 7. Test, then release

1. **Internal testing:** install from the Play testing link as a license tester and check each item:
   - Buy `gems_110`: the gems arrive.
   - Subscribe to `quiz_pass` (test renewals happen every few minutes), check the perks, then cancel.
   - Refund an order in Play Console › Order management: the gems are taken back.
   - Open the ad chest and claim each power-up token (real ad unit, signed callback).
   - Use 50:50, +5s and Skip with and without enough coins.
   - Reinstall the app and restore purchases.
   - Delete a test account.
2. **Closed testing** (personal accounts): at least 12 testers opted in for 14 days in a row, then **apply for production access**.
3. **Production:**
   - Set `GOOGLE_PLAY_ALLOW_TEST_PURCHASES=false`.
   - Create the release with a **staged rollout** (e.g. 10%, then 50%, then 100%).
   - Watch the backend logs for `SECURITY WARNING`, `[Billing]` and `[Ads]` lines.
4. **After the app is live:** link the app in AdMob to its Play listing, and check that AdMob reports `app-ads.txt` as verified.
