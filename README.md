# EcoStitch 🧵🌿

EcoStitch is an eco-conscious mobile application that empowers users to rescue discarded or unused garments and transform them into functional, artisanal new items (e.g., Denim → Tote bag, Linen Shirt → Apron).

## Project Structure (Step 3: FastAPI Preprocessing Backend)

```
EcoStitch/
├── app/                              # FastAPI Preprocessing Backend (Step 3)
│   ├── main.py                       # FastAPI application entrypoint & middleware
│   ├── config.py                     # Environment configuration (SUPABASE_URL, SERVICE_ROLE_KEY)
│   ├── routers/
│   │   └── garments.py               # POST /garments/{garment_id}/preprocess endpoint
│   └── services/
│       ├── supabase_client.py        # Supabase client with service_role key, storage & DB queries
│       └── preprocessing.py          # rembg background removal & OpenCV coin detection
├── migration.sql                     # Supabase SQL script to add preprocessing columns
├── requirements.txt                  # Python dependencies (fastapi, uvicorn, rembg, opencv, supabase)
├── .env.example                      # Template environment variables
├── .env                              # Local secret credentials (gitignored)
├── lib/                              # Flutter Mobile App (Steps 1 & 2)
│   ├── main.dart                     # Supabase initialization, anonymous auth, GoRouter
│   ├── config/
│   │   └── supabase_config.dart      # Flutter Supabase config
│   ├── services/
│   │   └── garment_upload_service.dart # Upload to garment-images bucket & insert into garments table
│   ├── screens/
│   │   ├── home_screen.dart          # Screen 1: Dashboard, Swing-tag card, Stat strip, Recent projects
│   │   └── capture_screen.dart       # Screen 2: Framing, Coin guide, User-triggered Continue upload
│   └── theme/
│       └── app_theme.dart            # Design tokens (greenDeep, thread, mintTop, ink)
├── web/                              # Interactive Web Preview & Flash Screen
│   ├── assets/                       # Custom Ec*Stitch logo assets
│   ├── index.html                    # Web UI with animated splash screen & Supabase integration
│   ├── style.css                     # Responsive styling engine
│   └── app.js                        # Client-side engine
└── pubspec.yaml                      # Flutter dependencies
```

## Step 3: FastAPI Preprocessing Pipeline

### 1. Database Migration
Before starting, run [migration.sql](file:///c:/Users/pc/Documents/EcoStitch/migration.sql) in your [Supabase SQL Editor](https://supabase.com/dashboard/project/pxwzpklkpbiycslxytqm/sql):
```sql
ALTER TABLE garments
ADD COLUMN IF NOT EXISTS cutout_image_url TEXT,
ADD COLUMN IF NOT EXISTS reference_object_detected BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS reference_object_pixel_diameter NUMERIC,
ADD COLUMN IF NOT EXISTS error_message TEXT;
```

### 2. Environment Configuration
Copy `.env.example` to `.env` and provide your `SUPABASE_SERVICE_ROLE_KEY`:
```env
SUPABASE_URL=https://pxwzpklkpbiycslxytqm.supabase.co
SUPABASE_SERVICE_ROLE_KEY=<your-service-role-secret-key>
```
*(Found in Supabase Dashboard -> Project Settings -> API -> `service_role` secret).*

### 3. Install Backend Dependencies
```bash
pip install -r requirements.txt
```

### 4. Run the FastAPI Server
```bash
uvicorn app.main:app --reload --port 8000
```
- Interactive API Docs: `http://localhost:8000/docs`
- Health Check: `http://localhost:8000/health`

### 5. Preprocess Endpoint Contract
`POST /garments/{garment_id}/preprocess`

**Process Flow**:
1. Fetches garment row from `garments` table by `garment_id` (404 if not found).
2. Sets status to `"preprocessing"`.
3. Downloads image from `garment-images` bucket.
4. Removes background using `rembg` (u2net model) to create transparent PNG cutout.
5. Detects reference coin via OpenCV `cv2.HoughCircles` (records pixel diameter).
6. Uploads cutout to `garment-images/{user_id}/{garment_id}_cutout.png`.
7. Updates database record to status `"preprocessed"` with `cutout_image_url`, `reference_object_detected`, and `reference_object_pixel_diameter`.
8. Returns JSON response:
```json
{
  "garment_id": "gmt_12345",
  "status": "preprocessed",
  "reference_object_detected": true,
  "reference_object_pixel_diameter": 128.4,
  "cutout_image_url": "user_id/gmt_12345_cutout.png"
}
```
