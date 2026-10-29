-- coursemaster.sql - test copy of the SQL in Manitoba/queries_root/ca.myblueprint.dem.coursemaster.named_queries.xml (plugin version 1.2.1)
-- Run in a SQL tool (e.g. DBeaver/SQL Developer) against the PowerSchool database.
-- Edits here do NOT change the plugin; copy any changes back into the CDATA block (without these comment lines).

WITH cfg AS (
	SELECT
		''                             AS school_ids
		,''                            AS powerscheduler_school_ids
		,1                             AS hs_courses_only
	FROM dual
),
yr AS (
	SELECT TO_NUMBER(TO_CHAR(SYSDATE, 'YYYY'))
		- CASE WHEN TO_NUMBER(TO_CHAR(SYSDATE, 'MM')) < 9 THEN 1 ELSE 0 END
		- 1990 AS yearid
	FROM dual
),
src AS (
	SELECT
		c.ID              AS course_id
		,c.COURSE_NUMBER  AS course_number
		,sc.SCHOOLID      AS schoolid
	FROM COURSES c
	LEFT JOIN cfg ON 1=1
	LEFT JOIN yr ON 1=1
	INNER JOIN SCHOOL_COURSE sc ON sc.COURSEID = c.ID
	WHERE sc.STATUS = 1
		AND sc.YEARID IN (yr.yearid, yr.yearid + 1)
		AND (cfg.school_ids IS NULL OR INSTR(',' || REPLACE(cfg.school_ids, ' ', '') || ',', ',' || sc.SCHOOLID || ',') > 0)
		AND (cfg.powerscheduler_school_ids IS NULL OR INSTR(',' || REPLACE(cfg.powerscheduler_school_ids, ' ', '') || ',', ',' || sc.SCHOOLID || ',') = 0)
		AND (cfg.hs_courses_only = 0 OR SUBSTR(TRIM(c.CODE), 1, 1) IN ('1', '2', '3', '4') OR NVL(c.CREDIT_HOURS, 0) > 0 OR NVL(c.MAXCREDIT, 0) > 0)
	UNION
	SELECT
		c.ID
		,c.COURSE_NUMBER
		,scc.SCHOOLID
	FROM SCHEDULECOURSECATALOGS scc
	LEFT JOIN cfg ON 1=1
	INNER JOIN SCHEDULECATALOGS cat ON scc.COURSECATALOGID = cat.ID
		AND cat.CURRENTVALUE = 1
	INNER JOIN COURSES c ON scc.COURSE_NUMBER = c.COURSE_NUMBER
	WHERE cfg.powerscheduler_school_ids IS NOT NULL
		AND INSTR(',' || REPLACE(cfg.powerscheduler_school_ids, ' ', '') || ',', ',' || scc.SCHOOLID || ',') > 0
		AND (cfg.school_ids IS NULL OR INSTR(',' || REPLACE(cfg.school_ids, ' ', '') || ',', ',' || scc.SCHOOLID || ',') > 0)
		AND (cfg.hs_courses_only = 0 OR SUBSTR(TRIM(c.CODE), 1, 1) IN ('1', '2', '3', '4') OR NVL(c.CREDIT_HOURS, 0) > 0 OR NVL(c.MAXCREDIT, 0) > 0)
),
course_rows AS (
	SELECT
		s.schoolid
		,c.COURSE_NUMBER                                             AS course_number
		,c.COURSE_NAME                                               AS course_name
		,c.CREDIT_HOURS                                              AS credit_hours
		,c.MAXCREDIT                                                 AS maxcredit
		,c.CODE                                                      AS code
		,PS_CUSTOMFIELDS.GETCF('Courses', c.ID, 'alt_course_number') AS alt_course_number
	FROM src s
	INNER JOIN COURSES c ON c.ID = s.course_id
),
codes AS (
	SELECT
		r.schoolid, r.course_name, r.credit_hours, r.maxcredit, r.code
		,CASE
			WHEN TRIM(r.alt_course_number) IS NULL THEN r.course_number
			WHEN TRIM(r.code) IS NULL THEN TRIM(r.alt_course_number)
			ELSE TRIM(r.alt_course_number) || '-' || TRIM(r.code)
		END                                                AS out_course_code
		,r.course_number                                   AS out_alt_code
	FROM course_rows r
)
SELECT DISTINCT
	k.out_course_code                                                              AS a_CourseCode
	,TO_CHAR(k.schoolid)                                                           AS b_SchoolCode
	,TRIM(TRANSLATE(k.course_name, '|' || CHR(9) || CHR(10) || CHR(13), '    '))  AS c_CourseName
	,CAST(NULL AS VARCHAR2(1))                                                     AS d_Description
	,CAST(NULL AS VARCHAR2(1))                                                     AS e_Discipline
	,CAST(NULL AS VARCHAR2(1))                                                     AS f_Department
	,CAST(NULL AS VARCHAR2(1))                                                     AS g_Type
	,CASE
		WHEN SUBSTR(TRIM(k.code), 1, 1) IN ('1', '2', '3', '4')
			THEN TO_CHAR(8 + TO_NUMBER(SUBSTR(TRIM(k.code), 1, 1)))
	END                                                                            AS h_Grade
	,RTRIM(TO_CHAR(
		CASE WHEN NVL(k.credit_hours, 0) <= 0.001 AND k.maxcredit > 0 THEN k.maxcredit ELSE k.credit_hours END,
		'FM9990.999'), '.')                                                        AS i_Credit
	,k.out_alt_code                                                                AS j_AltCourseCode
	,CAST(NULL AS VARCHAR2(1))                                                     AS k_CourseID
	,CAST(NULL AS VARCHAR2(1))                                                     AS l_GuidanceMessage
	,CAST(NULL AS VARCHAR2(1))                                                     AS m_CourseAttribute
	,CAST(NULL AS VARCHAR2(1))                                                     AS n_MaxGrade
FROM codes k
WHERE k.out_course_code IS NOT NULL
ORDER BY b_SchoolCode, a_CourseCode
