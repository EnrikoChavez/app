To run your backend locally, follow these steps in your terminal:
1. Navigate to the backend folder
cd /Users/enriko/projects/call_project/backend
2. Install the dependencies
Make sure you have the required Python libraries installed:
pip install -r requirements.txt
3. Start the FastAPI server
Run the following command to start the server. I recommend adding --host 0.0.0.0 so that if you test on a physical iPhone, it can actually see your Mac on the network:
uvicorn main:app --reload --host 0.0.0.0 --port 8000
4. Ensure Redis is running (Important)
Your backend uses Redis for OTP rate limiting (otp.py). If you don't have Redis running, the login process might crash.
If you have Homebrew installed, start it with: brew services start redis
If you don't need login right now, you can ignore this, but the /otp endpoints will fail.
5. Check the connection
Once it's running, you should see:
INFO: Uvicorn running on http://0.0.0.0:8000
Now, go to your browser and visit: http://localhost:8000/
If you see {"bananas": "okk"}, your local backend is live! 🍌
⚠️ A Note on baseURL:
If your backend is running locally on your Mac:
iOS Simulator: Can use http://localhost:8000
Physical iPhone: Must use your Mac's IP (e.g., http://192.168.1.50:8000). localhost will not work on a real devices.
