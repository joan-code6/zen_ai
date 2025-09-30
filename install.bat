@echo off
echo Installing backend server
cd backend
pip install -r requirements.txt
echo Backend server installation complete starting server
python app.py