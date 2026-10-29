-- studentcourses.sql - test copy of the SQL in Manitoba/queries_root/ca.myblueprint.dem.studentcourses.named_queries.xml (plugin version 1.2.1)
-- Run in a SQL tool (e.g. DBeaver/SQL Developer) against the PowerSchool database.
-- Edits here do NOT change the plugin; copy any changes back into the CDATA block (without these comment lines).

WITH cfg AS (
	SELECT
		''                             AS school_ids
		,'F1,S1,S2,Y1'                 AS store_codes
		,7                             AS min_student_grade
		,8                             AS min_course_grade
		,1                             AS accept_exclude_from_gpa
		,1                             AS hs_courses_only
	FROM dual
),
yr AS (
	SELECT TO_NUMBER(TO_CHAR(SYSDATE, 'YYYY'))
		- CASE WHEN TO_NUMBER(TO_CHAR(SYSDATE, 'MM')) < 9 THEN 1 ELSE 0 END
		- 1990 AS yearid
	FROM dual
),
stored AS (
	SELECT
		s.STUDENT_NUMBER                                             AS student_number
		,sg.COURSE_NUMBER                                            AS course_number
		,sg.COURSE_NAME                                              AS course_name
		,t.LASTDAY                                                   AS lastday
		,sg.GRADE                                                    AS mark
		,sg.EARNEDCRHRS                                              AS earned
		,sg.POTENTIALCRHRS                                           AS potential
		,CAST(NULL AS NUMBER)                                        AS credit_hours
		,c.MAXCREDIT                                                 AS maxcredit
		,PS_CUSTOMFIELDS.GETCF('Courses', c.ID, 'alt_course_number') AS alt_course_number
		,c.CODE                                                      AS code
		,sg.GRADE                                                    AS grade_sort
		,1                                                           AS src
	FROM STOREDGRADES sg
	LEFT JOIN cfg ON 1=1
	INNER JOIN STUDENTS s ON sg.STUDENTID = s.ID
		AND s.GRADE_LEVEL >= cfg.min_student_grade
	INNER JOIN TERMS t ON t.ID = sg.TERMID
		AND t.SCHOOLID = sg.SCHOOLID
	INNER JOIN COURSES c ON sg.COURSE_NUMBER = c.COURSE_NUMBER
	WHERE sg.GRADE_LEVEL >= cfg.min_course_grade
		AND INSTR(',' || REPLACE(cfg.store_codes, ' ', '') || ',', ',' || sg.STORECODE || ',') > 0
		AND (cfg.school_ids IS NULL OR INSTR(',' || REPLACE(cfg.school_ids, ' ', '') || ',', ',' || s.SCHOOLID || ',') > 0)
		AND s.ENROLL_STATUS IN (-1, 0)
		AND (NVL(sg.EXCLUDEFROMGPA, 0) = 0 OR cfg.accept_exclude_from_gpa = 1)
		AND (sg.POTENTIALCRHRS > 0 OR sg.EARNEDCRHRS > 0)
		AND (cfg.hs_courses_only = 0 OR SUBSTR(TRIM(c.CODE), 1, 1) IN ('1', '2', '3', '4') OR sg.GRADE_LEVEL >= 9)
),
current_cc AS (
	SELECT
		s.STUDENT_NUMBER                                             AS student_number
		,cc.COURSE_NUMBER                                            AS course_number
		,c.COURSE_NAME                                               AS course_name
		,CAST(NULL AS DATE)                                          AS lastday
		,CAST(NULL AS VARCHAR2(50))                                  AS mark
		,CAST(NULL AS NUMBER)                                        AS earned
		,CAST(NULL AS NUMBER)                                        AS potential
		,c.CREDIT_HOURS                                              AS credit_hours
		,c.MAXCREDIT                                                 AS maxcredit
		,PS_CUSTOMFIELDS.GETCF('Courses', c.ID, 'alt_course_number') AS alt_course_number
		,c.CODE                                                      AS code
		,CAST(NULL AS VARCHAR2(50))                                  AS grade_sort
		,2                                                           AS src
	FROM CC cc
	LEFT JOIN cfg ON 1=1
	LEFT JOIN yr ON 1=1
	INNER JOIN COURSES c ON cc.COURSE_NUMBER = c.COURSE_NUMBER
	INNER JOIN TERMS t ON t.ID = cc.TERMID
		AND t.YEARID = yr.yearid
		AND t.SCHOOLID = cc.SCHOOLID
	INNER JOIN STUDENTS s ON cc.STUDENTID = s.ID
		AND s.GRADE_LEVEL >= cfg.min_student_grade
		AND s.ENROLL_STATUS IN (0, -1)
	WHERE NOT EXISTS (
			SELECT 1
			FROM STOREDGRADES sg2
			WHERE sg2.STUDENTID = cc.STUDENTID
				AND sg2.COURSE_NUMBER = cc.COURSE_NUMBER
				AND sg2.SECTIONID = cc.SECTIONID
				AND (sg2.POTENTIALCRHRS > 0 OR sg2.EARNEDCRHRS > 0)
		)
		AND (cfg.school_ids IS NULL OR INSTR(',' || REPLACE(cfg.school_ids, ' ', '') || ',', ',' || s.SCHOOLID || ',') > 0)
		AND (cfg.hs_courses_only = 0 OR SUBSTR(TRIM(c.CODE), 1, 1) IN ('1', '2', '3', '4')
			OR (s.GRADE_LEVEL >= 9 AND (NVL(c.CREDIT_HOURS, 0) > 0 OR NVL(c.MAXCREDIT, 0) > 0)))
),
combined AS (
	SELECT student_number, course_number, course_name, lastday, mark, earned, potential, credit_hours, maxcredit, alt_course_number, code, grade_sort, src FROM stored
	UNION ALL
	SELECT student_number, course_number, course_name, lastday, mark, earned, potential, credit_hours, maxcredit, alt_course_number, code, grade_sort, src FROM current_cc
),
ranked AS (
	SELECT
		x.student_number
		,x.course_number
		,x.course_name
		,x.lastday
		,x.mark
		,x.earned
		,x.potential
		,x.credit_hours
		,x.maxcredit
		,x.alt_course_number
		,x.code
		,x.lastday AS dt
		,ROW_NUMBER() OVER (
			PARTITION BY x.student_number, x.course_number, x.lastday
			ORDER BY NVL(x.earned, -1) DESC, x.src, NVL(x.grade_sort, ' ') DESC) AS rn
	FROM combined x
	WHERE x.course_number IS NOT NULL
),
codes AS (
	SELECT
		r.student_number
		,r.course_number
		,r.course_name
		,r.lastday
		,r.mark
		,r.dt
		,CASE
			WHEN TRIM(r.alt_course_number) IS NULL THEN r.course_number
			WHEN TRIM(r.code) IS NULL THEN TRIM(r.alt_course_number)
			ELSE TRIM(r.alt_course_number) || '-' || TRIM(r.code)
		END                                                AS out_course_code
		,r.course_number                                   AS out_alt_code
		,CASE
			WHEN r.dt IS NOT NULL AND r.dt <= SYSDATE THEN r.earned
			WHEN NVL(NVL(r.credit_hours, r.potential), 0) <= 0.001 AND r.maxcredit > 0 THEN r.maxcredit
			ELSE NVL(r.credit_hours, r.potential)
		END                                                AS credit_value
	FROM ranked r
	WHERE r.rn = 1
)
SELECT
	TO_CHAR(x.student_number)                                                      AS a_StudentID
	,x.out_course_code                                                             AS b_CourseCode
	,TRIM(TRANSLATE(x.course_name, '|' || CHR(9) || CHR(10) || CHR(13), '    '))  AS c_CourseName
	,TO_CHAR(x.dt, 'YYYY-MM-DD')                                                   AS d_DateCompleted
	,TRIM(x.mark)                                                                  AS e_FinalMark
	,RTRIM(TO_CHAR(x.credit_value, 'FM9990.999'), '.')                             AS f_Credit
	,x.out_alt_code                                                                AS g_AlternateCourseCode
	,CAST(NULL AS VARCHAR2(1))                                                     AS h_CourseID
	,CAST(NULL AS VARCHAR2(1))                                                     AS i_SubstituteID
FROM codes x
ORDER BY x.student_number, NVL(x.lastday, TO_DATE('1900-01-01', 'YYYY-MM-DD')) DESC, x.course_number
