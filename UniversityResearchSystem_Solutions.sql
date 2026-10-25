/*
  University Research System database assignment
  Dialect: Microsoft SQL Server (T-SQL)
  Source schema: UniversityResearchSystem.bak

  Run the query sections in the restored assignment database. DDL sections
  create the requested objects. The sample transaction is parameterized and
  deliberately not executed by this script because it inserts business data.
*/

/* Q1. Researchers and their projects, retaining researchers with no project. */
SELECT r.Id AS ResearcherId,
       CONCAT_WS(' ', r.FirstName, r.MiddleName, r.LastName) AS ResearcherName,
       p.Id AS ProjectId,
       p.Title AS ProjectTitle
FROM dbo.Researcher AS r
LEFT JOIN dbo.WorksOn AS w ON w.ResearcherId = r.Id
LEFT JOIN dbo.ResearchProject AS p ON p.Id = w.ProjectId
ORDER BY r.LastName, r.FirstName, r.Id, p.Id;
GO

/* Q2. Projects that have at least one grant allocation. */
SELECT p.Id AS ProjectId, p.Title,
       CONCAT_WS(' ', r.FirstName, r.MiddleName, r.LastName) AS LeadResearcher,
       r.Email
FROM dbo.ResearchProject AS p
JOIN dbo.Researcher AS r ON r.Id = p.LeaderId
WHERE EXISTS (SELECT 1 FROM dbo.Funds AS f WHERE f.ProjectId = p.Id)
ORDER BY p.Id;
GO

/* Q3. Cartesian product: every researcher paired with every publication. */
SELECT r.Id AS ResearcherId,
       CONCAT_WS(' ', r.FirstName, r.MiddleName, r.LastName) AS ResearcherName,
       p.Id AS PublicationId, p.Title AS PublicationTitle
FROM dbo.Researcher AS r
CROSS JOIN dbo.Publication AS p;
GO
/* Q3 explanation: row count = researchers × publications; this can explode,
   wastes CPU/network, and invents researcher-publication associations. Use
   Publishes for actual authorship relationships. */

/* Q4. Supervisors and the people they supervise. */
SELECT sup.Id AS SupervisorId,
       CONCAT_WS(' ', sup.FirstName, sup.MiddleName, sup.LastName) AS SupervisorName,
       sub.Id AS SupervisedId,
       CONCAT_WS(' ', sub.FirstName, sub.MiddleName, sub.LastName) AS SupervisedName,
       s.SupervisionStartDate, s.Role
FROM dbo.Supervises AS s
JOIN dbo.Researcher AS sup ON sup.Id = s.SupervisorId
JOIN dbo.Researcher AS sub ON sub.Id = s.SupervisedId
ORDER BY sup.LastName, sub.LastName, s.SupervisionStartDate;
GO

/* Q5. Published researchers not working on an active project. */
SELECT r.Id AS ResearcherId,
       CONCAT_WS(' ', r.FirstName, r.MiddleName, r.LastName) AS ResearcherName
FROM dbo.Researcher AS r
WHERE EXISTS (SELECT 1 FROM dbo.Publishes AS pa WHERE pa.ResearcherId = r.Id)
  AND NOT EXISTS
      (SELECT 1
       FROM dbo.WorksOn AS w
       JOIN dbo.ResearchProject AS p ON p.Id = w.ProjectId
       WHERE w.ResearcherId = r.Id AND p.Status = 'Active')
ORDER BY r.LastName, r.FirstName, r.Id;
GO

/* Q6. Top five citation positions, including ties at position five. */
SELECT TOP (5) WITH TIES Id AS PublicationId, Title, Type, CitationCount
FROM dbo.Publication
ORDER BY CitationCount DESC;
GO

/* Q7. Second page, 10 researchers per page; Id makes paging deterministic. */
SELECT Id, FirstName, MiddleName, LastName, Email, DateOfBirth, Building, RoomNumber
FROM dbo.Researcher
ORDER BY LastName, FirstName, Id
OFFSET 10 ROWS FETCH NEXT 10 ROWS ONLY;
GO

/* Q8. Both statements request the first three rows in LastName order, but
   tied last names can make the selected rows differ unless a unique tie-breaker
   is added. OFFSET-FETCH supports page numbers/page sizes; TOP also supports
   PERCENT and WITH TIES and works in more query contexts. */

/* Q9. Unique index within each building, oldest birth date first. */
SELECT Id AS ResearcherId, FirstName, LastName, Building, DateOfBirth,
       ROW_NUMBER() OVER
         (PARTITION BY Building ORDER BY DateOfBirth, Id) AS BuildingIndex
FROM dbo.Researcher
ORDER BY Building, DateOfBirth, Id;
GO

/* Q10. Rank by citations within publication type; ties share a rank. */
SELECT Title, Type, CitationCount,
       RANK() OVER
         (PARTITION BY Type ORDER BY CitationCount DESC) AS PublicationRank
FROM dbo.Publication
ORDER BY Type, PublicationRank, Title;
GO

/* Q11. Budget ranking within each status (RANK has gaps; DENSE_RANK has none). */
SELECT Id AS ProjectId, Title, Status, Budget,
       RANK() OVER (PARTITION BY Status ORDER BY Budget DESC) AS RankWithGaps,
       DENSE_RANK() OVER (PARTITION BY Status ORDER BY Budget DESC) AS RankWithoutGaps
FROM dbo.ResearchProject
ORDER BY Status, Budget DESC, Id;
GO
/* If two projects tie at rank 1, RANK assigns the next row 3; DENSE_RANK
   assigns it 2. */

/* Q12. Count all researchers' publications (zero included), then split into 4. */
WITH PublicationCounts AS
(
    SELECT r.Id AS ResearcherId, r.FirstName, r.MiddleName, r.LastName,
           COUNT(pa.PublicationId) AS PublicationCount
    FROM dbo.Researcher AS r
    LEFT JOIN dbo.Publishes AS pa ON pa.ResearcherId = r.Id
    GROUP BY r.Id, r.FirstName, r.MiddleName, r.LastName
)
SELECT ResearcherId, CONCAT_WS(' ', FirstName, MiddleName, LastName) AS ResearcherName,
       PublicationCount,
       NTILE(4) OVER (ORDER BY PublicationCount DESC, ResearcherId) AS GroupNumber
FROM PublicationCounts
ORDER BY GroupNumber, PublicationCount DESC, ResearcherId;
GO

/* Q13. Logical processing order: FROM/JOIN, WHERE, GROUP BY, HAVING, SELECT,
   ORDER BY, then TOP or OFFSET-FETCH row limiting. */

/* Q14. Aggregate aliases are unavailable to WHERE and aggregates are filtered
   with HAVING, after grouping. */
SELECT ResearcherId, COUNT(*) AS ProjectCount
FROM dbo.WorksOn
GROUP BY ResearcherId
HAVING COUNT(*) > 2;
GO

/* Q15. Name, lowercase email, and age as of today. */
SELECT CONCAT_WS(' ', FirstName, MiddleName, LastName) AS FullName,
       LOWER(Email) AS EmailLowercase,
       DATEDIFF(YEAR, DateOfBirth, CONVERT(date, GETDATE()))
         - CASE WHEN DATEADD(YEAR, DATEDIFF(YEAR, DateOfBirth, CONVERT(date, GETDATE())),
                             DateOfBirth) > CONVERT(date, GETDATE())
                THEN 1 ELSE 0 END AS AgeYears
FROM dbo.Researcher;
GO

/* Q16. Duration in days and start month/year. */
SELECT Id AS ProjectId, Title, StartDate, EndDate,
       DATEDIFF(DAY, StartDate, COALESCE(EndDate, CONVERT(date, GETDATE()))) AS DurationDays,
       MONTH(StartDate) AS StartMonth,
       YEAR(StartDate) AS StartYear
FROM dbo.ResearchProject;
GO

/* Q17. Exact email domain match. */
SELECT Id AS ResearcherId, FirstName, LastName, Email
FROM dbo.Researcher
WHERE LOWER(SUBSTRING(Email, CHARINDEX('@', Email) + 1, 255)) = 'university.edu'
  AND CHARINDEX('@', Email) > 0;
GO

/* Q18. Replace missing optional values. */
SELECT Id, FirstName, COALESCE(MiddleName, 'N/A') AS MiddleName, LastName,
       Email, DateOfBirth, Building,
       COALESCE(RoomNumber, 'N/A') AS RoomNumber
FROM dbo.Researcher;
GO

/* Q19. Budget bands; NULL budgets are explicitly marked Unknown. */
SELECT Id AS ProjectId, Title, Budget,
       CASE WHEN Budget IS NULL THEN 'Unknown'
            WHEN Budget < 50000 THEN 'Small'
            WHEN Budget <= 150000 THEN 'Medium'
            ELSE 'Large' END AS BudgetCategory
FROM dbo.ResearchProject;
GO

/* Q20. Total budgets for researchers who lead projects. */
SELECT r.Id AS ResearcherId,
       CONCAT_WS(' ', r.FirstName, r.MiddleName, r.LastName) AS ResearcherName,
       SUM(p.Budget) AS TotalBudgetManaged
FROM dbo.Researcher AS r
JOIN dbo.ResearchProject AS p ON p.LeaderId = r.Id
GROUP BY r.Id, r.FirstName, r.MiddleName, r.LastName
ORDER BY ResearcherName;
GO

/* Q21. Buildings with more than three researchers. */
SELECT COALESCE(Building, 'N/A') AS Building, COUNT(*) AS ResearcherCount
FROM dbo.Researcher
GROUP BY Building
HAVING COUNT(*) > 3
ORDER BY ResearcherCount DESC, Building;
GO

/* Q22. Citation aggregates by type; AVG/SUM ignore NULL citation counts. */
SELECT Type, AVG(CAST(CitationCount AS decimal(12,2))) AS AverageCitationCount,
       SUM(CitationCount) AS TotalCitations, COUNT(*) AS PublicationCount
FROM dbo.Publication
GROUP BY Type
HAVING AVG(CAST(CitationCount AS decimal(12,2))) > 50
ORDER BY Type;
GO

/* Q23. More than two distinct projects and over 60 committed hours. */
SELECT ResearcherId, COUNT(DISTINCT ProjectId) AS ProjectCount,
       SUM(HoursPerWeek) AS TotalHoursPerWeek
FROM dbo.WorksOn
GROUP BY ResearcherId
HAVING COUNT(DISTINCT ProjectId) > 2
   AND SUM(HoursPerWeek) > 60;
GO

/* Q24. Projects over the average non-NULL budget. */
SELECT Id AS ProjectId, Title, Budget
FROM dbo.ResearchProject
WHERE Budget > (SELECT AVG(Budget) FROM dbo.ResearchProject)
ORDER BY Budget DESC, Id;
GO

/* Q25. Publication count above the average count in the same building.
   Researchers with zero publications are included in each building average. */
WITH PublicationCounts AS
(
    SELECT r.Id AS ResearcherId, r.Building, COUNT(pa.PublicationId) AS PublicationCount
    FROM dbo.Researcher AS r
    LEFT JOIN dbo.Publishes AS pa ON pa.ResearcherId = r.Id
    GROUP BY r.Id, r.Building
)
SELECT pc.ResearcherId, r.FirstName, r.LastName, pc.Building, pc.PublicationCount
FROM PublicationCounts AS pc
JOIN dbo.Researcher AS r ON r.Id = pc.ResearcherId
WHERE pc.PublicationCount >
      (SELECT AVG(CAST(pc2.PublicationCount AS decimal(12,2)))
       FROM PublicationCounts AS pc2
       WHERE pc2.Building = pc.Building
          OR (pc2.Building IS NULL AND pc.Building IS NULL))
ORDER BY pc.Building, pc.PublicationCount DESC, pc.ResearcherId;
GO

/* Q26. Researchers supervising at least one other researcher. */
SELECT r.Id AS ResearcherId, r.FirstName, r.LastName
FROM dbo.Researcher AS r
WHERE EXISTS (SELECT 1 FROM dbo.Supervises AS s WHERE s.SupervisorId = r.Id);
GO

/* Q27. Each project with a correlated count of assigned researchers. */
SELECT p.Id AS ProjectId, p.Title,
       (SELECT COUNT(*) FROM dbo.WorksOn AS w WHERE w.ProjectId = p.Id) AS ResearcherCount
FROM dbo.ResearchProject AS p
ORDER BY p.Id;
GO

/* Q28. Second-highest distinct, non-NULL project budget; no ranking/paging. */
SELECT MAX(Budget) AS SecondHighestDistinctBudget
FROM dbo.ResearchProject
WHERE Budget < (SELECT MAX(Budget) FROM dbo.ResearchProject);
GO

/* Q29. Researchers involved in projects who have authored no publications. */
SELECT r.Id AS ResearcherId, r.FirstName, r.LastName
FROM dbo.Researcher AS r
WHERE EXISTS (SELECT 1 FROM dbo.WorksOn AS w WHERE w.ResearcherId = r.Id)
  AND NOT EXISTS (SELECT 1 FROM dbo.Publishes AS pa WHERE pa.ResearcherId = r.Id)
ORDER BY r.LastName, r.Id;
GO

/* Q30. Researchers who supervise others and lead one or more projects. */
SELECT r.Id AS ResearcherId,
       CONCAT_WS(' ', r.FirstName, r.MiddleName, r.LastName) AS ResearcherName
FROM dbo.Researcher AS r
WHERE EXISTS (SELECT 1 FROM dbo.Supervises AS s WHERE s.SupervisorId = r.Id)
  AND EXISTS (SELECT 1 FROM dbo.ResearchProject AS p WHERE p.LeaderId = r.Id)
ORDER BY r.LastName, r.Id;
GO

/* Q31. Function returning project days from StartDate to EndDate or today. */
CREATE OR ALTER FUNCTION dbo.ufn_ProjectActiveDays
(
    @ProjectId varchar(10)
)
RETURNS int
AS
BEGIN
    DECLARE @Days int;
    SELECT @Days = DATEDIFF(DAY, StartDate, COALESCE(EndDate, CONVERT(date, GETDATE())))
    FROM dbo.ResearchProject
    WHERE Id = @ProjectId;
    RETURN @Days;
END;
GO

/* Q32. Inline table-valued function: projects, role, and weekly hours. */
CREATE OR ALTER FUNCTION dbo.ufn_ResearcherProjects
(
    @ResearcherId varchar(10)
)
RETURNS TABLE
AS
RETURN
(
    SELECT p.Id AS ProjectId, p.Title AS ProjectTitle, w.Role, w.HoursPerWeek
    FROM dbo.WorksOn AS w
    JOIN dbo.ResearchProject AS p ON p.Id = w.ProjectId
    WHERE w.ResearcherId = @ResearcherId
);
GO

/* Q33. Aggregate summary; a multi-statement TVF suits the required
   output-table construction / branching use cases, but an inline TVF is
   preferable for simple single-query logic because it can be optimized with
   the caller (MSTVF may have weaker cardinality estimates). */
CREATE OR ALTER FUNCTION dbo.ufn_ResearcherStatistics
(
    @ResearcherId varchar(10)
)
RETURNS @Stats TABLE
(
    TotalProjects int NOT NULL,
    TotalPublications int NOT NULL,
    TotalHoursPerWeek bigint NOT NULL,
    AverageCitationsPerPublication decimal(12,2) NULL
)
AS
BEGIN
    INSERT INTO @Stats
        (TotalProjects, TotalPublications, TotalHoursPerWeek, AverageCitationsPerPublication)
    SELECT
        (SELECT COUNT(*) FROM dbo.WorksOn AS w WHERE w.ResearcherId = @ResearcherId),
        (SELECT COUNT(*) FROM dbo.Publishes AS pa WHERE pa.ResearcherId = @ResearcherId),
        COALESCE((SELECT SUM(CONVERT(bigint, w.HoursPerWeek))
                  FROM dbo.WorksOn AS w WHERE w.ResearcherId = @ResearcherId), 0),
        (SELECT AVG(CONVERT(decimal(12,2), p.CitationCount))
         FROM dbo.Publishes AS pa
         JOIN dbo.Publication AS p ON p.Id = pa.PublicationId
         WHERE pa.ResearcherId = @ResearcherId);
    RETURN;
END;
GO

/* Q34. Search index on project status and start date. */
IF NOT EXISTS
   (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'dbo.ResearchProject')
     AND name = N'IX_ResearchProject_Status_StartDate')
    CREATE NONCLUSTERED INDEX IX_ResearchProject_Status_StartDate
        ON dbo.ResearchProject (Status, StartDate DESC)
        INCLUDE (Id, Title);
GO
/* Q35. A table can have one clustered index (or be a heap). A clustered
   index stores the table rows in key order; a nonclustered index stores a
   separate key/row-locator structure. Adding a clustered index to a heap
   reorganizes the rows and rebuilds nonclustered row locators from heap RIDs
   to clustered keys; the existing nonclustered indexes remain. */

/* Q36. Cover Email searches that return FirstName and LastName. */
IF NOT EXISTS
   (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'dbo.Researcher')
     AND name = N'IX_Researcher_Email_Cover')
    CREATE NONCLUSTERED INDEX IX_Researcher_Email_Cover
        ON dbo.Researcher (Email)
        INCLUDE (FirstName, LastName);
GO
/* A covering index contains all search and output columns, so SQL Server can
   answer this lookup from the index without a base-table key lookup. */

/* Q37. Active-project summary. */
CREATE OR ALTER VIEW dbo.ActiveProjectSummary
AS
    SELECT p.Id AS ProjectId, p.Title AS ProjectTitle,
           CONCAT_WS(' ', r.FirstName, r.MiddleName, r.LastName) AS LeaderName,
           COALESCE(team.TeamMemberCount, 0) AS TeamMemberCount,
           COALESCE(team.TotalHoursPerWeek, 0) AS TotalHoursPerWeek,
           p.Budget AS TotalBudget
    FROM dbo.ResearchProject AS p
    JOIN dbo.Researcher AS r ON r.Id = p.LeaderId
    LEFT JOIN
    (
        SELECT ProjectId, COUNT(*) AS TeamMemberCount,
               SUM(CONVERT(bigint, COALESCE(HoursPerWeek, 0))) AS TotalHoursPerWeek
        FROM dbo.WorksOn
        GROUP BY ProjectId
    ) AS team ON team.ProjectId = p.Id
    WHERE p.Status = 'Active';
GO

/* Q38. Indexed view with a row for every researcher, including zero-publication
   researchers. SQL Server indexed views disallow outer joins, so this small
   summary source table is maintained transactionally by the triggers below. */
IF OBJECT_ID(N'dbo.ResearcherPublicationStatSource', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.ResearcherPublicationStatSource
    (
        ResearcherId varchar(10) NOT NULL
            CONSTRAINT PK_ResearcherPublicationStatSource PRIMARY KEY,
        ResearcherName varchar(152) NOT NULL,
        TotalPublications bigint NOT NULL,
        CONSTRAINT FK_ResearcherPublicationStatSource_Researcher
            FOREIGN KEY (ResearcherId) REFERENCES dbo.Researcher(Id) ON DELETE CASCADE
    );
END;
GO

UPDATE stat
SET ResearcherName = CONCAT_WS(' ', r.FirstName, r.MiddleName, r.LastName),
    TotalPublications = counts.TotalPublications
FROM dbo.ResearcherPublicationStatSource AS stat
JOIN dbo.Researcher AS r ON r.Id = stat.ResearcherId
CROSS APPLY
(
    SELECT COUNT_BIG(*) AS TotalPublications
    FROM dbo.Publishes AS pa
    WHERE pa.ResearcherId = r.Id
) AS counts;

INSERT dbo.ResearcherPublicationStatSource
    (ResearcherId, ResearcherName, TotalPublications)
SELECT r.Id, CONCAT_WS(' ', r.FirstName, r.MiddleName, r.LastName),
       counts.TotalPublications
FROM dbo.Researcher AS r
CROSS APPLY
(
    SELECT COUNT_BIG(*) AS TotalPublications
    FROM dbo.Publishes AS pa
    WHERE pa.ResearcherId = r.Id
) AS counts
WHERE NOT EXISTS
      (SELECT 1 FROM dbo.ResearcherPublicationStatSource AS stat
       WHERE stat.ResearcherId = r.Id);
GO

CREATE OR ALTER TRIGGER dbo.trg_ResearcherPublicationStatSource_Researcher
ON dbo.Researcher
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE stat
       SET ResearcherName = CONCAT_WS(' ', i.FirstName, i.MiddleName, i.LastName)
    FROM dbo.ResearcherPublicationStatSource AS stat
    JOIN inserted AS i ON i.Id = stat.ResearcherId;

    INSERT dbo.ResearcherPublicationStatSource
        (ResearcherId, ResearcherName, TotalPublications)
    SELECT i.Id, CONCAT_WS(' ', i.FirstName, i.MiddleName, i.LastName), 0
    FROM inserted AS i
    WHERE NOT EXISTS
          (SELECT 1 FROM dbo.ResearcherPublicationStatSource AS stat
           WHERE stat.ResearcherId = i.Id);
END;
GO

CREATE OR ALTER TRIGGER dbo.trg_ResearcherPublicationStatSource_Publishes
ON dbo.Publishes
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    ;WITH AffectedResearchers AS
    (
        SELECT ResearcherId FROM inserted
        UNION
        SELECT ResearcherId FROM deleted
    )
    UPDATE stat
       SET TotalPublications = counts.TotalPublications
    FROM dbo.ResearcherPublicationStatSource AS stat
    JOIN AffectedResearchers AS affected
      ON affected.ResearcherId = stat.ResearcherId
    CROSS APPLY
    (
        SELECT COUNT_BIG(*) AS TotalPublications
        FROM dbo.Publishes AS pa
        WHERE pa.ResearcherId = stat.ResearcherId
    ) AS counts;
END;
GO

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET ANSI_PADDING ON;
SET ANSI_WARNINGS ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET ARITHABORT ON;
SET NUMERIC_ROUNDABORT OFF;
GO
DROP INDEX IF EXISTS UX_ResearcherPublicationStats
    ON dbo.ResearcherPublicationStats;
GO
CREATE OR ALTER VIEW dbo.ResearcherPublicationStats
WITH SCHEMABINDING
AS
    SELECT stat.ResearcherId, stat.ResearcherName, stat.TotalPublications
    FROM dbo.ResearcherPublicationStatSource AS stat;
GO
CREATE UNIQUE CLUSTERED INDEX UX_ResearcherPublicationStats
    ON dbo.ResearcherPublicationStats (ResearcherId);
GO
/* Q39. Indexed-view requirements: schema binding; two-part base object names; a
   unique clustered index first; COUNT_BIG for grouped aggregates; deterministic
   expressions; required SET options; and supported view syntax (no outer
   joins, TOP, DISTINCT, subqueries, or UNION). The Q38 source table and triggers
   provide zero-count rows that an indexed view cannot produce with an outer
   join. The indexed view stores a clustered copy of that summary for reads;
   the tradeoff is source-table storage and trigger work on researcher/authorship
   writes. Prefer this for frequent reads when the write overhead is acceptable;
   use a regular view when you don't want a separately maintained summary. */

/* Q40. Add a researcher to a project with validation and return codes. */
CREATE OR ALTER PROCEDURE dbo.AddResearcherToProject
    @ResearcherId varchar(10),
    @ProjectId varchar(10),
    @JoinDate date,
    @Role varchar(50),
    @HoursPerWeek int
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        IF NOT EXISTS (SELECT 1 FROM dbo.Researcher WHERE Id = @ResearcherId)
            RETURN -1;
        IF NOT EXISTS (SELECT 1 FROM dbo.ResearchProject WHERE Id = @ProjectId)
            RETURN -1;

        BEGIN TRANSACTION;
        IF EXISTS
           (SELECT 1 FROM dbo.WorksOn WITH (UPDLOCK, HOLDLOCK)
            WHERE ResearcherId = @ResearcherId AND ProjectId = @ProjectId)
        BEGIN
            ROLLBACK TRANSACTION;
            RETURN -1;
        END;

        INSERT dbo.WorksOn (ResearcherId, ProjectId, JoinDate, Role, HoursPerWeek)
        VALUES (@ResearcherId, @ProjectId, @JoinDate, @Role, @HoursPerWeek);
        COMMIT TRANSACTION;
        RETURN 0;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        RETURN -1;
    END CATCH;
END;
GO

/* Q41. Change Pending to Active only if assigned researchers and a grant exist. */
CREATE OR ALTER PROCEDURE dbo.UpdateProjectStatus
    @ProjectId varchar(10)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        IF NOT EXISTS (SELECT 1 FROM dbo.ResearchProject
                       WHERE Id = @ProjectId AND Status = 'Pending')
            RETURN -1;
        IF NOT EXISTS (SELECT 1 FROM dbo.WorksOn WHERE ProjectId = @ProjectId)
            RETURN -1;
        IF NOT EXISTS (SELECT 1 FROM dbo.Funds WHERE ProjectId = @ProjectId)
            RETURN -1;

        UPDATE dbo.ResearchProject
        SET Status = 'Active'
        WHERE Id = @ProjectId AND Status = 'Pending';
        IF @@ROWCOUNT = 1 RETURN 0;
        RETURN -1;
    END TRY
    BEGIN CATCH
        RETURN -1;
    END CATCH;
END;
GO

/* Q42. Output counts for a researcher. */
CREATE OR ALTER PROCEDURE dbo.GetResearcherWorkSummary
    @ResearcherId varchar(10),
    @TotalProjects int OUTPUT,
    @TotalPublications int OUTPUT,
    @TotalHoursPerWeek bigint OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT @TotalProjects = COUNT(*) FROM dbo.WorksOn WHERE ResearcherId = @ResearcherId;
    SELECT @TotalPublications = COUNT(*) FROM dbo.Publishes WHERE ResearcherId = @ResearcherId;
    SELECT @TotalHoursPerWeek = COALESCE(SUM(CONVERT(bigint, HoursPerWeek)), 0)
    FROM dbo.WorksOn WHERE ResearcherId = @ResearcherId;
END;
GO

/* Q43. Reject an insert that leaves any affected researcher on > 5 projects. */
CREATE OR ALTER TRIGGER dbo.trg_WorksOn_MaxFiveProjects
ON dbo.WorksOn
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS
       (SELECT i.ResearcherId
        FROM (SELECT DISTINCT ResearcherId FROM inserted) AS i
        JOIN dbo.WorksOn AS w ON w.ResearcherId = i.ResearcherId
        GROUP BY i.ResearcherId
        HAVING COUNT(*) > 5)
    BEGIN
        ROLLBACK TRANSACTION;
        THROW 51001, 'A researcher cannot be assigned to more than five projects.', 1;
    END;
END;
GO

/* Q44. AFTER trigger: evaluate the committed EndDate and then update Status. */
CREATE OR ALTER TRIGGER dbo.trg_ResearchProject_CompletePastEndDate
ON dbo.ResearchProject
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE p
       SET Status = 'Completed'
    FROM dbo.ResearchProject AS p
    JOIN inserted AS i ON i.Id = p.Id
    LEFT JOIN deleted AS d ON d.Id = i.Id
    WHERE i.EndDate < CONVERT(date, GETDATE())
      AND ISNULL(p.Status, '') <> 'Completed'
      AND (d.Id IS NULL OR d.EndDate IS NULL OR d.EndDate <> i.EndDate);
END;
GO
/* AFTER is appropriate because the row must first be written so the trigger
   can inspect its actual EndDate; the second UPDATE marks it completed. */

/* Q45. Audit old/new amounts for every Grants row updated. */
IF OBJECT_ID(N'dbo.GrantAudit', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.GrantAudit
    (
        AuditId bigint IDENTITY(1,1) NOT NULL PRIMARY KEY,
        GrantId varchar(10) NOT NULL,
        OldAmount decimal(12,2) NOT NULL,
        NewAmount decimal(12,2) NOT NULL,
        ModifiedBy sysname NOT NULL,
        ModifiedDate datetime2(0) NOT NULL
            CONSTRAINT DF_GrantAudit_ModifiedDate DEFAULT (SYSDATETIME())
    );
END;
GO
CREATE OR ALTER TRIGGER dbo.trg_Grants_AuditUpdates
ON dbo.Grants
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    INSERT dbo.GrantAudit (GrantId, OldAmount, NewAmount, ModifiedBy, ModifiedDate)
    SELECT i.Id, d.Amount, i.Amount, SYSTEM_USER, SYSDATETIME()
    FROM inserted AS i
    JOIN deleted AS d ON d.Id = i.Id;
END;
GO

/* Q46. Atomic project + leader assignment + grant allocation.
   Execute by calling the procedure with valid, unused IDs and an existing grant. */
CREATE OR ALTER PROCEDURE dbo.CreateFundedProject
    @ProjectId varchar(10),
    @Title varchar(200),
    @StartDate date,
    @Budget decimal(12,2),
    @LeaderId varchar(10),
    @JoinDate date,
    @Role varchar(50),
    @HoursPerWeek int,
    @GrantId varchar(10),
    @AllocationAmount decimal(12,2),
    @AllocationDate date
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        IF NOT EXISTS (SELECT 1 FROM dbo.Researcher WHERE Id = @LeaderId)
            THROW 51002, 'The project leader does not exist.', 1;
        IF NOT EXISTS (SELECT 1 FROM dbo.Grants WHERE Id = @GrantId)
            THROW 51003, 'The grant does not exist.', 1;
        IF EXISTS (SELECT 1 FROM dbo.ResearchProject WHERE Id = @ProjectId)
            THROW 51004, 'The project ID is already in use.', 1;

        BEGIN TRANSACTION;
        INSERT dbo.ResearchProject (Id, Title, StartDate, Budget, Status, LeaderId)
        VALUES (@ProjectId, @Title, @StartDate, @Budget, 'Pending', @LeaderId);

        INSERT dbo.WorksOn (ResearcherId, ProjectId, JoinDate, Role, HoursPerWeek)
        VALUES (@LeaderId, @ProjectId, @JoinDate, @Role, @HoursPerWeek);

        INSERT dbo.Funds (GrantId, ProjectId, AllocationAmount, AllocationDate)
        VALUES (@GrantId, @ProjectId, @AllocationAmount, @AllocationDate);
        COMMIT TRANSACTION;
        RETURN 0;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        RETURN -1;
    END CATCH;
END;
GO
/* Q47. ACID: Atomicity means all three inserts above commit or none do;
   Consistency preserves foreign keys and project rules; Isolation prevents
   another session observing a partially-created project; Durability means a
   committed project, assignment, and funding allocation survive a restart. */

/* Q48. IN and EXISTS are commonly optimized as equivalent semi-joins. Neither
   is universally faster; indexes, uniqueness, selectivity, row counts,
   statistics, and the chosen execution plan determine performance. */
-- Query A
SELECT r.*
FROM dbo.Researcher AS r
WHERE r.Id IN
      (SELECT w.ResearcherId FROM dbo.WorksOn AS w WHERE w.ProjectId = 'P001');
GO
-- Query B
SELECT r.*
FROM dbo.Researcher AS r
WHERE EXISTS (SELECT 1 FROM dbo.WorksOn AS w
              WHERE w.ResearcherId = r.Id AND w.ProjectId = 'P001');
GO
/* Q49. Useful indexes / checks for the slow active-project query:
   1) ResearchProject(Status, StartDate DESC) INCLUDE (Id, Title).
   2) WorksOn(ProjectId, ResearcherId) to support the project-to-team join.
   3) Researcher.Id is already the clustered primary key, so its row lookup
      returns FirstName/LastName without another covering index.
   4) Refresh statistics and inspect the actual execution plan / logical reads.
   The WHERE predicate on p.Status does not remove projects without a team, so
   retain LEFT JOIN if those projects must remain in the output. */
IF NOT EXISTS
   (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'dbo.WorksOn')
     AND name = N'IX_WorksOn_ProjectId_ResearcherId')
    CREATE NONCLUSTERED INDEX IX_WorksOn_ProjectId_ResearcherId
        ON dbo.WorksOn (ProjectId, ResearcherId);
GO

/* Q50. For repeated Top-10 cited publications with authors:
   A) Repeated query: simplest/fresh data, but duplicated text and no shared
      interface.
   B) View: reusable and current, but does not store results; ORDER BY/TOP
      belongs in the consuming query and an indexed view cannot use TOP.
   C) Stored procedure: reusable, parameterizable, plan-cache friendly, and
      can return authors; result remains current, with execution permission
      control.
   D) Indexed view: can speed supported materialized aggregates, but this
      author join/top-10 ordering is not an indexed-view shape and every write
      carries maintenance cost.
   Choose a stored procedure for a stable reusable Top-10 query with authors;
   support it with a citation index and an authorship index. */
CREATE OR ALTER PROCEDURE dbo.GetTopCitedPublications
AS
BEGIN
    SET NOCOUNT ON;
    WITH TopPublications AS
    (
        SELECT TOP (10) Id, Title, Type, CitationCount
        FROM dbo.Publication
        ORDER BY CitationCount DESC, Id
    )
    SELECT p.Id AS PublicationId, p.Title, p.Type, p.CitationCount,
           pa.ResearcherId,
           CONCAT_WS(' ', r.FirstName, r.MiddleName, r.LastName) AS ResearcherName
    FROM TopPublications AS p
    LEFT JOIN dbo.Publishes AS pa ON pa.PublicationId = p.Id
    LEFT JOIN dbo.Researcher AS r ON r.Id = pa.ResearcherId
    ORDER BY p.CitationCount DESC, p.Id, pa.ResearcherId;
END;
GO
IF NOT EXISTS
   (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'dbo.Publication')
     AND name = N'IX_Publication_CitationCount')
    CREATE NONCLUSTERED INDEX IX_Publication_CitationCount
        ON dbo.Publication (CitationCount DESC, Id)
        INCLUDE (Title, Type);
GO
IF NOT EXISTS
   (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'dbo.Publishes')
     AND name = N'IX_Publishes_PublicationId')
    CREATE NONCLUSTERED INDEX IX_Publishes_PublicationId
        ON dbo.Publishes (PublicationId, ResearcherId);
GO
