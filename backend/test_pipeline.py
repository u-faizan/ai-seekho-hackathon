import sys
from database.database import get_db, SessionLocal
from services.agents import run_pipeline

db = SessionLocal()
try:
    result = run_pipeline(
        raw_input="A sales report showing declining orders in Lahore by 25% over the last week.",
        user={"uid": "test"},
        db_session=db
    )
    
    print("\n--- INSIGHT ---")
    print(result["insight"])
    
    print("\n--- IMPACT ---")
    print(result["impact"])
    
    print("\n--- RECOMMENDED ACTION ---")
    print(result["recommended_action"])
    
    print("\n--- EXECUTION LOGS ---")
    for log in result["execution_logs"]:
        print(log)
        
except Exception as e:
    import traceback
    traceback.print_exc()
finally:
    db.close()
