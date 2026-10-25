# University Research System — Database Assignment

The executable answer key is [UniversityResearchSystem_Solutions.sql](UniversityResearchSystem_Solutions.sql). It follows the SQL Server dialect used by the supplied backup file and is arranged by question/task order.

## Source and schema

- Assignment: Universty_Exam_Questions.pdf
- Database: UniversityResearchSystem.bak
- Engine used for verification: SQL Server 2025 Express, T-SQL
- The backup was restored into a separate local database named UniversityResearchSystem_Exam; the supplied backup was not changed.
- Main relationships used by the answers: ResearchProject.LeaderId -> Researcher.Id; WorksOn links researchers to projects; Publishes links researchers to publications; Funds links projects to grants; Supervises is a researcher-to-researcher relationship.
- The restored backup contains 100 researchers, 101 research projects, 102 WorksOn rows, 100 publications, 133 Publishes rows, 100 grants, and 101 Funds rows.

The full schema uses Researcher.Id, ResearchProject.Id, and Publication.Id as keys. ResearchProject.Budget, Status, and EndDate, Researcher.MiddleName, Building, and RoomNumber, WorksOn.Role and HoursPerWeek, and Publication.CitationCount can be NULL. The query answers account for those nullable columns where relevant. Q38 includes every researcher, including those with zero publications; trigger-maintained summary rows let the indexed view avoid an unsupported outer join.

## Running the solution

Run the SQL file in the restored assignment database in SQL Server Management Studio or with sqlcmd -d UniversityResearchSystem_Exam. The query sections return their requested result sets. The DDL sections create the requested functions, indexes, views, procedures, and triggers.

CreateFundedProject is parameterized and not invoked by the script because it inserts a project, assignment, and funding allocation.

## Numbering check

The PDF visibly contains questions 1 through 50. The SQL answer sections follow the printed numbering, including Q29 (researchers on projects with no publications), Q30 (researchers who supervise and lead), Q31-Q33 (function tasks), and Q50 (the top-10 publications approaches). Some hidden PDF text layers duplicate blocks and show phantom numbering; those artifacts are not used as assignment questions.
