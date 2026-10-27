"""Boundary between the application and the screening model.

The model implementation lives behind ScreeningModelAdapter (adapter.py). The
application owns authentication, profiles, the assessment lifecycle, activity
statuses, result persistence and progress; see service.py.
"""
