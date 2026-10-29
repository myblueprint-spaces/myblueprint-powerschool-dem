-- conedsections.sql - test copy of the SQL in Ontario/queries_root/ca.myblueprint.dem.conedsections.named_queries.xml (plugin version 1.2.0)
-- Run in a SQL tool (e.g. DBeaver/SQL Developer) against the PowerSchool database.
-- Edits here do NOT change the plugin; copy any changes back into the CDATA block (without these comment lines).

WITH cfg AS (
	SELECT
		''                             AS coned_school_ids
	FROM dual
),
yr AS (
	SELECT TO_NUMBER(TO_CHAR(SYSDATE, 'YYYY'))
		- CASE WHEN TO_NUMBER(TO_CHAR(SYSDATE, 'MM')) < 9 THEN 1 ELSE 0 END
		- 1990 AS yearid
	FROM dual
)
SELECT
	TO_CHAR(s.SCHOOLID)                                                            AS a_SchoolID
	,TRIM(TRANSLATE(sc.NAME, '|' || CHR(9) || CHR(10) || CHR(13), '    '))         AS b_SchoolName
	,s.COURSE_NUMBER                                                               AS c_CourseNumber
	,s.SECTION_NUMBER                                                              AS d_SectionNumber
	,TO_CHAR(s.TERMID)                                                             AS e_TermID
	,TRIM(TRANSLATE(t.NAME, '|' || CHR(9) || CHR(10) || CHR(13), '    '))          AS f_TermName
	,TO_CHAR(s.NO_OF_STUDENTS)                                                     AS g_NoOfStudents
	,TO_CHAR(s.MAXENROLLMENT)                                                      AS h_MaxEnrollment
FROM SECTIONS s
LEFT JOIN cfg ON 1=1
LEFT JOIN yr ON 1=1
INNER JOIN SCHOOLS sc ON sc.SCHOOL_NUMBER = s.SCHOOLID
INNER JOIN TERMS t ON t.ID = s.TERMID
	AND t.SCHOOLID = s.SCHOOLID
WHERE cfg.coned_school_ids IS NOT NULL
	AND INSTR(',' || REPLACE(cfg.coned_school_ids, ' ', '') || ',', ',' || s.SCHOOLID || ',') > 0
	AND t.YEARID IN (yr.yearid, yr.yearid + 1)
ORDER BY s.SCHOOLID, s.COURSE_NUMBER, s.SECTION_NUMBER
