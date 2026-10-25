from app.db.database import Base, engine
from app.models import Assessment, ChildProfile, ScreeningResult


def init_db():
    Base.metadata.create_all(bind=engine)
    print("INTELLISCREEN database tables created successfully!")


if __name__ == "__main__":
    init_db()