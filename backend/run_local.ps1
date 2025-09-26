# PowerShell helper to run the Flask app locally
python -m venv venv; .\venv\Scripts\Activate.ps1
pip install -r requirements.txt
$env:FLASK_APP = "app.py"
flask run
