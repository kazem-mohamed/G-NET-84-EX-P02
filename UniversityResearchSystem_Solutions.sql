/*
  University Research System — assignment answers
  SQL Server (T-SQL), based on UniversityResearchSystem.bak

  Run this file in the restored assignment database. It contains both query
  answers and the requested database objects. CreateFundedProject is defined
  here but not called, so the file won't add sample project data.
*/

/* Q1. Show each researcher and any project they're assigned to. The LEFT JOINs
   keep researchers who aren't assigned to a project. */
SELECT r.Id AS ResearcherId,
       CONCAT_WS(' ', r.FirstName, r.MiddleName, r.LastName) AS ResearcherName,
       p.Id AS ProjectId,
       p.Title AS ProjectTitle
FROM dbo.Researcher AS r
LEFT JOIN dbo.WorksOn AS w ON w.ResearcherId = r.Id
LEFT JOIN dbo.ResearchProject AS p ON p.Id = w.ProjectId
ORDER BY r.LastName, r.FirstName, r.Id, p.Id;
GO

/* Q2. Return funded projects with the lead researcher's name and email. */
SELECT p.Id AS ProjectId, p.Title,
       CONCAT_WS(' ', r.FirstName, r.MiddleName, r.LastName) AS LeadResearcher,
       r.Email
FROM dbo.ResearchProject AS p
JOIN dbo.Researcher AS r ON r.Id = p.LeaderId
WHERE EXISTS (SELECT 1 FROM dbo.Funds AS f WHERE f.ProjectId = p.Id)
ORDER BY p.Id;
GO

/* Q3. CROSS JOIN pairs every researcher with every publication. */
SELECT r.Id AS ResearcherId,
       CONCAT_WS(' ', r.FirstName, r.MiddleName, r.LastName) AS ResearcherName,
       p.Id AS PublicationId, p.Title AS PublicationTitle
FROM dbo.Researcher AS r
CROSS JOIN dbo.Publication AS p;
GO
/* On the supplied database this returns 10,000 pairs. It doesn't show who
   actually wrote what; Publishes holds those authorship links. */

/* Q4. The aliases make it clear who supervises whom. */
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

/* Q5. Find researchers with publications and no active project assignment. */
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

/* Q6. WITH TIES keeps every publication tied with the fifth citation count. */
SELECT TOP (5) WITH TIES Id AS PublicationId, Title, Type, CitationCount
FROM dbo.Publication
ORDER BY CitationCount DESC;
GO

/* Q7. Skip the first ten researchers, then return the next ten. Id breaks ties. */
SELECT Id, FirstName, MiddleName, LastName, Email, DateOfBirth, Building, RoomNumber
FROM dbo.Researcher
ORDER BY LastName, FirstName, Id
OFFSET 10 ROWS FETCH NEXT 10 ROWS ONLY;
GO

/* Q8. Both statements ask for the first three rows by LastName. If last names
   tie, either query can choose a different row unless you add a unique
   tie-breaker. OFFSET-FETCH is handy for paging; TOP also supports PERCENT and
   WITH TIES. */

/* Q9. Number researchers separately within each building, oldest first. */
SELECT Id AS ResearcherId, FirstName, LastName, Building, DateOfBirth,
       ROW_NUMBER() OVER
         (PARTITION BY Building ORDER BY DateOfBirth, Id) AS BuildingIndex
FROM dbo.Researcher
ORDER BY Building, DateOfBirth, Id;
GO

/* Q10. Rank by citation count inside each publication type. Ties share a rank. */
SELECT Title, Type, CitationCount,
       RANK() OVER
         (PARTITION BY Type ORDER BY CitationCount DESC) AS PublicationRank
FROM dbo.Publication
ORDER BY Type, PublicationRank, Title;
GO

/* Q11. Show both ranking styles so the gaps are easy to compare. */
SELECT Id AS ProjectId, Title, Status, Budget,
       RANK() OVER (PARTITION BY Status ORDER BY Budget DESC) AS RankWithGaps,
       DENSE_RANK() OVER (PARTITION BY Status ORDER BY Budget DESC) AS RankWithoutGaps
FROM dbo.ResearchProject
ORDER BY Status, Budget DESC, Id;
GO
/* For example, if two projects tie at 1, RANK gives the next project 3;
   DENSE_RANK gives it 2. */

/* Q12. Count publications first so researchers with none still get a group. */
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

/* Q13. SQL Server processes these clauses in this order:
   FROM/JOIN, WHERE, GROUP BY, HAVING, SELECT, ORDER BY, then row limiting
   with TOP or OFFSET-FETCH. */

/* Q14. WHERE runs before grouping, so it can't filter ProjectCount. Use HAVING
   to test the aggregate after each researcher has been grouped. */
SELECT ResearcherId, COUNT(*) AS ProjectCount
FROM dbo.WorksOn
GROUP BY ResearcherId
HAVING COUNT(*) > 2;
GO

/* Q15. Build the name, lowercase the email, and adjust age if the birthday
   hasn't happened yet this year. */
SELECT CONCAT_WS(' ', FirstName, MiddleName, LastName) AS FullName,
       LOWER(Email) AS EmailLowercase,
       DATEDIFF(YEAR, DateOfBirth, CONVERT(date, GETDATE()))
         - CASE WHEN DATEADD(YEAR, DATEDIFF(YEAR, DateOfBirth, CONVERT(date, GETDATE())),
                             DateOfBirth) > CONVERT(date, GETDATE())
                THEN 1 ELSE 0 END AS AgeYears
FROM dbo.Researcher;
GO

/* Q16. Use today's date for projects that don't have an EndDate yet. */
SELECT Id AS ProjectId, Title, StartDate, EndDate,
       DATEDIFF(DAY, StartDate, COALESCE(EndDate, CONVERT(date, GETDATE()))) AS DurationDays,
       MONTH(StartDate) AS StartMonth,
       YEAR(StartDate) AS StartYear
FROM dbo.ResearchProject;
GO

/* Q17. Compare the part of the email after @ with the requested domain. */
SELECT Id AS ResearcherId, FirstName, LastName, Email
FROM dbo.Researcher
WHERE LOWER(SUBSTRING(Email, CHARINDEX('@', Email) + 1, 255)) = 'university.edu'
  AND CHARINDEX('@', Email) > 0;
GO

/* Q18. Show N/A for the two optional fields when they're NULL. */
SELECT Id, FirstName, COALESCE(MiddleName, 'N/A') AS MiddleName, LastName,
       Email, DateOfBirth, Building,
       COALESCE(RoomNumber, 'N/A') AS RoomNumber
FROM dbo.Researcher;
GO

/* Q19. NULL budgets don't fit a band, so label them Unknown. */
SELECT Id AS ProjectId, Title, Budget,
       CASE WHEN Budget IS NULL THEN 'Unknown'
            WHEN Budget < 50000 THEN 'Small'
            WHEN Budget <= 150000 THEN 'Medium'
            ELSE 'Large' END AS BudgetCategory
FROM dbo.ResearchProject;
GO

/* Q20. Sum the budgets of projects led by each researcher. */
SELECT r.Id AS ResearcherId,
       CONCAT_WS(' ', r.FirstName, r.MiddleName, r.LastName) AS ResearcherName,
       SUM(p.Budget) AS TotalBudgetManaged
FROM dbo.Researcher AS r
JOIN dbo.ResearchProject AS p ON p.LeaderId = r.Id
GROUP BY r.Id, r.FirstName, r.MiddleName, r.LastName
ORDER BY ResearcherName;
GO

/* Q21. Keep only buildings with at least four researchers. */
SELECT COALESCE(Building, 'N/A') AS Building, COUNT(*) AS ResearcherCount
FROM dbo.Researcher
GROUP BY Building
HAVING COUNT(*) > 3
ORDER BY ResearcherCount DESC, Building;
GO

/* Q22. AVG and SUM skip NULL citation counts; COUNT still counts every paper. */
SELECT Type, AVG(CAST(CitationCount AS decimal(12,2))) AS AverageCitationCount,
       SUM(CitationCount) AS TotalCitations, COUNT(*) AS PublicationCount
FROM dbo.Publication
GROUP BY Type
HAVING AVG(CAST(CitationCount AS decimal(12,2))) > 50
ORDER BY Type;
GO

/* Q23. Apply both thresholds to each researcher's assignments. */
SELECT ResearcherId, COUNT(DISTINCT ProjectId) AS ProjectCount,
       SUM(HoursPerWeek) AS TotalHoursPerWeek
FROM dbo.WorksOn
GROUP BY ResearcherId
HAVING COUNT(DISTINCT ProjectId) > 2
   AND SUM(HoursPerWeek) > 60;
GO

/* Q24. AVG ignores NULL budgets, as required for the comparison. */
SELECT Id AS ProjectId, Title, Budget
FROM dbo.ResearchProject
WHERE Budget > (SELECT AVG(Budget) FROM dbo.ResearchProject)
ORDER BY Budget DESC, Id;
GO

/* Q25. The LEFT JOIN counts researchers with no publications as zero. Compare
   each count with the average for that building. */
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

/* Q26. EXISTS returns each supervisor once, even if they supervise several people. */
SELECT r.Id AS ResearcherId, r.FirstName, r.LastName
FROM dbo.Researcher AS r
WHERE EXISTS (SELECT 1 FROM dbo.Supervises AS s WHERE s.SupervisorId = r.Id);
GO

/* Q27. The subquery counts assignments for the current project. */
SELECT p.Id AS ProjectId, p.Title,
       (SELECT COUNT(*) FROM dbo.WorksOn AS w WHERE w.ProjectId = p.Id) AS ResearcherCount
FROM dbo.ResearchProject AS p
ORDER BY p.Id;
GO

/* Q28. Find the greatest budget below the maximum: the second-highest distinct
   value, without ranking functions or OFFSET-FETCH. */
SELECT MAX(Budget) AS SecondHighestDistinctBudget
FROM dbo.ResearchProject
WHERE Budget < (SELECT MAX(Budget) FROM dbo.ResearchProject);
GO

/* Q29. Keep researchers with a project assignment and no Publishes rows. */
SELECT r.Id AS ResearcherId, r.FirstName, r.LastName
FROM dbo.Researcher AS r
WHERE EXISTS (SELECT 1 FROM dbo.WorksOn AS w WHERE w.ResearcherId = r.Id)
  AND NOT EXISTS (SELECT 1 FROM dbo.Publishes AS pa WHERE pa.ResearcherId = r.Id)
ORDER BY r.LastName, r.Id;
GO

/* Q30. Both EXISTS checks must succeed for the same researcher. */
SELECT r.Id AS ResearcherId,
       CONCAT_WS(' ', r.FirstName, r.MiddleName, r.LastName) AS ResearcherName
FROM dbo.Researcher AS r
WHERE EXISTS (SELECT 1 FROM dbo.Supervises AS s WHERE s.SupervisorId = r.Id)
  AND EXISTS (SELECT 1 FROM dbo.ResearchProject AS p WHERE p.LeaderId = r.Id)
ORDER BY r.LastName, r.Id;
GO

/* Q31. Return the number of days through EndDate, or today if the project is open. */
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

/* Q32. Return the projects this researcher works on with their role and hours. */
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

/* Q33. A multi-statement TVF is useful when the result takes several steps or
   needs branching and intermediate work. For a single SELECT, an inline TVF is
   usually easier for the optimizer to fold into the caller's query. */
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

/* Q34. This key order supports searches by status followed by start date. */
IF NOT EXISTS
   (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'dbo.ResearchProject')
     AND name = N'IX_ResearchProject_Status_StartDate')
    CREATE NONCLUSTERED INDEX IX_ResearchProject_Status_StartDate
        ON dbo.ResearchProject (Status, StartDate DESC)
        INCLUDE (Id, Title);
GO
/* Q35. A table has at most one clustered index; without one, it's a heap.
   The clustered index stores the rows by its key. Nonclustered indexes store
   separate keys and row locators. Creating a clustered index on a heap
   reorganizes the rows and rebuilds nonclustered indexes to use the clustered
   key instead of heap row IDs; the nonclustered indexes aren't removed. */

/* Q36. Email is the search key; the INCLUDE columns cover the requested output. */
IF NOT EXISTS
   (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'dbo.Researcher')
     AND name = N'IX_Researcher_Email_Cover')
    CREATE NONCLUSTERED INDEX IX_Researcher_Email_Cover
        ON dbo.Researcher (Email)
        INCLUDE (FirstName, LastName);
GO
/* Because the index has Email, FirstName, and LastName, SQL Server can answer
   this lookup without going back to the table for the names. */

/* Q37. One row per active project, including projects with no team assignments. */
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

/* Q38. The indexed view needs to include researchers with zero publications.
   SQL Server won't allow an outer join in an indexed view, so a small helper
   table stores one row per researcher. The triggers below keep it current. */
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET ANSI_PADDING ON;
SET ANSI_WARNINGS ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET ARITHABORT ON;
SET NUMERIC_ROUNDABORT OFF;
GO
IF OBJECT_ID(N'dbo.ResearcherPublicationStats', N'V') IS NOT NULL
   AND EXISTS
       (SELECT 1 FROM sys.indexes
        WHERE object_id = OBJECT_ID(N'dbo.ResearcherPublicationStats')
          AND name = N'UX_ResearcherPublicationStats')
    DROP INDEX UX_ResearcherPublicationStats ON dbo.ResearcherPublicationStats;
GO
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

CREATE OR ALTER VIEW dbo.ResearcherPublicationStats
WITH SCHEMABINDING
AS
    SELECT stat.ResearcherId, stat.ResearcherName, stat.TotalPublications
    FROM dbo.ResearcherPublicationStatSource AS stat;
GO
CREATE UNIQUE CLUSTERED INDEX UX_ResearcherPublicationStats
    ON dbo.ResearcherPublicationStats (ResearcherId);
GO
/* Q39. An indexed view needs SCHEMABINDING and a unique clustered index before
   any other index. Grouped views also need COUNT_BIG(*). Its expressions must
   be deterministic, the required SET options must be on, and features such as
   outer joins, TOP, DISTINCT, subqueries, and UNION aren't allowed.

   This view reads the Q38 summary table, whose triggers include researchers
   with zero publications. The index makes repeated reads fast, but every
   authorship or researcher change also updates the summary and indexed view.
   Use a regular view when that write cost or extra stored data isn't worthwhile. */

/* Q40. Validate both IDs and reject duplicate assignments before inserting. */
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

/* Q41. Only activate a pending project after it has a team member and funding. */
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

/* Q42. Return project count, publication count, and weekly hours through OUTPUTs. */
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

/* Q43. Check every researcher touched by a multi-row insert. */
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

/* Q44. AFTER is appropriate here: the EndDate has been saved when the trigger
   checks it. The status update won't loop because EndDate hasn't changed. */
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

/* Q45. Keep one audit row for each Grants row changed, including multi-row updates. */
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

/* Q46. All three inserts share one transaction. Call the procedure with unused
   project details and an existing researcher and grant. */
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
/* Q47. In this example, atomicity means the project, assignment, and funding
   either all save or none do. Consistency preserves their foreign keys.
   Isolation keeps other sessions from seeing only part of the setup.
   Durability means the committed records remain after a restart. */

/* Q48. SQL Server often turns both forms into a semi-join, so neither is
   automatically faster. Indexes, row counts, and the actual plan matter. */
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
/* Q49. A few ways to help this query:
   - The ResearchProject index from Q34 filters active projects and orders them
     by StartDate while covering Id and Title.
   - The WorksOn index below helps find team members for each project.
   - Researcher.Id is already the clustered key, so another name index would
     add little for this lookup.
   - After large data changes, update statistics and check the actual plan and
     logical reads.
   Keep the LEFT JOINs if projects without team members should still appear. */
IF NOT EXISTS
   (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'dbo.WorksOn')
     AND name = N'IX_WorksOn_ProjectId_ResearcherId')
    CREATE NONCLUSTERED INDEX IX_WorksOn_ProjectId_ResearcherId
        ON dbo.WorksOn (ProjectId, ResearcherId);
GO

/* Q50. A query is quickest to start with, but its text gets repeated.
   A view gives one reusable definition and always reads current data, but the
   caller still has to sort and limit the results. A stored procedure gives
   callers one reusable entry point and can return the authors with each paper.
   An indexed view stores results for faster reads, but this top-10 query and
   author join don't fit indexed-view restrictions, and maintaining it adds
   write cost. I'd use a stored procedure here, backed by citation and
   authorship indexes. */
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
