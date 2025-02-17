# Fitbit Health Dashboard

A comprehensive health data dashboard for tracking and analyzing Fitbit data. Built with React, TypeScript, and Supabase.

## Features

- User authentication with role-based access control
- Fitbit device integration and data synchronization
- Real-time health data visualization
- Group management for research studies
- Data export capabilities
- Invitation code system for participant onboarding

## Tech Stack

- React 18
- TypeScript
- Vite
- Tailwind CSS
- Supabase
- Recharts
- Lucide React

## Development

1. Clone the repository
2. Install dependencies:
   ```bash
   npm install
   ```
3. Create a `.env` file with your Supabase and Fitbit credentials:
   ```
   VITE_SUPABASE_URL=your_supabase_url
   VITE_SUPABASE_ANON_KEY=your_supabase_anon_key
   VITE_FITBIT_CLIENT_ID=your_fitbit_client_id
   VITE_FITBIT_CLIENT_SECRET=your_fitbit_client_secret
   VITE_FITBIT_REDIRECT_URI=your_fitbit_redirect_uri
   ```
4. Start the development server:
   ```bash
   npm run dev
   ```

## License

MIT