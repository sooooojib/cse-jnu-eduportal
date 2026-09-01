# Database Architecture & Ground-Zero Design

This directory contains the complete database architectural specification, entity-relationship diagrams, constraints, concurrency analysis, and data dictionary for the new **CSE JnU EduPortal** platform.

---

## 📚 Database Specification Index

| Document | Topic | Description |
| :--- | :--- | :--- |
| [`database_design.md`](database_design.md) | **Architecture & Design Philosophy** | Ground-zero derivation, entity inventory (15 tables), standard naming conventions, and domain boundaries. |
| [`entity_relationships.md`](entity_relationships.md) | **Relationships & ER Diagram** | Cardinalities (1:1, 1:N, M:N), foreign key delete/update cascade rules, and full Mermaid ER diagram. |
| [`constraints_and_indexes.md`](constraints_and_indexes.md) | **Constraints & Concurrency** | Race condition safeguards (attendance spikes, mutual exclusion counseling, schedule collisions), Check constraints, and compound indexes. |
| [`data_dictionary.md`](data_dictionary.md) | **Complete Data Dictionary** | Comprehensive table-by-table schema catalog with datatypes, nullabilities, default values, and validations. |

---

## 🛡️ Key Architectural Guarantees

1. **Zero Legacy Reproduction**: The database is engineered completely from ground zero directly from the functional requirements.
2. **Atomic Mutual Exclusion**: Database-level serializable transactions prevent double-booking of counseling slots and race conditions.
3. **Partial Indexes for Concurrency**: Ensures at most one active attendance session per course, one pending signup per student, and one pending semester petition per student.
4. **Strict Isolation**: The database is completely isolated behind the backend API gateway with zero direct access from Flutter clients.
