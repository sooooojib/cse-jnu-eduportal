# Database Architecture & Ground-Zero Design

This directory contains the database architectural specifications, entity-relationship models, Cloud Firestore schemas, and security rule specifications for **CSE JnU EduPortal**.

> [!NOTE]
> **Active Database Platform**: The production database is **Cloud Firestore (NoSQL)**. See [`firestore_data_model.md`](firestore_data_model.md) and [`firestore_security_model.md`](firestore_security_model.md) for active document collections and security policies. Relational documents (`database_design.md`, `entity_relationships.md`, `data_dictionary.md`) serve as domain entity reference designs.

---

## 📚 Database Specification Index

| Document | Topic | Description |
| :--- | :--- | :--- |
| **[`firestore_data_model.md`](firestore_data_model.md)** | **🔥 Cloud Firestore Data Model** | Active NoSQL schema, 12 collection structures, composite document IDs, and index configurations. |
| **[`firestore_security_model.md`](firestore_security_model.md)** | **🛡️ Firestore Security Model** | Role-based declarative security rules, custom claims inspection, and schema validators. |
| [`database_design.md`](database_design.md) | **Domain Architecture & Entities** | Ground-zero entity models (15 entities), standard naming conventions, and domain boundaries. |
| [`entity_relationships.md`](entity_relationships.md) | **Relationships & ER Diagram** | Cardinalities (1:1, 1:N, M:N), lifecycle cascade rules, and full Mermaid ER diagram. |
| [`constraints_and_indexes.md`](constraints_and_indexes.md) | **Constraints & Concurrency** | Race condition safeguards (attendance spikes, mutual exclusion counseling, schedule collisions). |
| [`data_dictionary.md`](data_dictionary.md) | **Complete Data Dictionary** | Comprehensive entity catalog with datatypes, nullabilities, default values, and validations. |

---

## 🛡️ Key Architectural Guarantees

1. **Sub-Millisecond Declarative Security**: Read and write operations are strictly evaluated against token custom claims (`request.auth.token.role`) at the database engine level.
2. **Deterministic Uniqueness**: Composite document IDs (e.g. `${sessionId}_${studentId}`) eliminate write race conditions and prevent duplicate attendance entries.
3. **Built-in Offline Persistence**: Documents and queries are cached to local disk on mobile devices automatically for instant offline startup.
4. **Zero Client Trust for Admin Tasks**: Privileged operations (account provisioning, role elevation) are restricted to Firebase Cloud Functions utilizing the Firebase Admin SDK.
