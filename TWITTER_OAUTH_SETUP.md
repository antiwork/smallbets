# Twitter OAuth Setup Guide

This guide explains how to set up Twitter OAuth integration for Small Bets.

## Features

- **Sign in with X**: Users can sign in using their X (Twitter) account
- **Account Linking**: Existing users can link their X account to their profile
- **Automatic Profile Updates**: When linking, the user's Twitter username and profile URL are automatically updated

## Setup Instructions

### 1. Create Twitter Developer App

1. Go to [Twitter Developer Portal](https://developer.twitter.com/en/portal/projects-and-apps)
2. Create a new project and app
3. In your app settings, go to "User authentication settings"
4. Configure OAuth 2.0 settings:
   - App permissions: Read
   - Type of App: Web App
   - Callback URLs: `https://your-domain.com/auth/twitter2/callback`
   - Website URL: `https://your-domain.com`

### 2. Environment Variables

Add the following to your `.env` file:

```
TWITTER_CLIENT_ID=your_client_id_here
TWITTER_CLIENT_SECRET=your_client_secret_here
```

### 3. Install Dependencies

Run `bundle install` to install the required gems:
- `omniauth`
- `omniauth-twitter2`
- `omniauth-rails_csrf_protection`

### 4. Database Migration

Run the migration to add Twitter OAuth fields:

```bash
rails db:migrate
```

## Usage

### Sign In Page
- Users can click "Continue with X" on the sign-in page
- If they have an account with a matching email, it will be linked
- If not, a new account will be created (if email is provided)

### Profile Page
- Users can connect their X account from their profile page
- Once connected, their Twitter username will be displayed
- The Twitter URL field will be automatically populated

## Technical Details

### Database Changes
- Added `twitter_uid` (string, unique index)
- Added `twitter_username` (string)
- Existing `twitter_url` field is reused for profile links

### OAuth Flow
1. User clicks "Continue with X"
2. Redirected to Twitter OAuth
3. After authorization, redirected to `/auth/twitter2/callback`
4. `OauthCallbacksController` handles the response
5. User is either signed in or their account is linked

### Security
- Uses OAuth 2.0 with PKCE
- CSRF protection enabled
- Unique constraints on Twitter UID
- Proper error handling for failed authentications