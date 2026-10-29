-- student.sql - test copy of the SQL in Manitoba/queries_root/ca.myblueprint.dem.student.named_queries.xml (plugin version 1.2.0)
-- Run in a SQL tool (e.g. DBeaver/SQL Developer) against the PowerSchool database.
-- Edits here do NOT change the plugin; copy any changes back into the CDATA block (without these comment lines).

WITH cfg AS (
	SELECT
		''                             AS school_ids
		,7                             AS min_student_grade
		,0                             AS include_legal_name
		,0                             AS append_middle_name
	FROM dual
)
SELECT
	TO_CHAR(s.STUDENT_NUMBER)                                                       AS a_StudentID
	,s.STATE_STUDENTNUMBER                                                          AS b_StudentNumber
	,TRIM(TRANSLATE(s.FIRST_NAME || NVL2(sm.MIDDLE_NAME, ' ' || sm.MIDDLE_NAME, NULL), '|' || CHR(9) || CHR(10) || CHR(13), '    ')) AS c_FirstName
	,TRIM(TRANSLATE(s.LAST_NAME, '|' || CHR(9) || CHR(10) || CHR(13), '    '))                                          AS d_LastName
	,s.GENDER                                                                       AS e_Gender
	,TO_CHAR(s.DOB, 'YYYY-MM-DD')                                                   AS f_DateOfBirth
	,CAST(NULL AS VARCHAR2(1))                                                      AS g_Email
	,TO_CHAR(s.GRADE_LEVEL)                                                         AS h_Grade
	,CASE s.ENROLL_STATUS WHEN 0 THEN '1' WHEN -1 THEN '2' ELSE '3' END             AS i_Status
	,TO_CHAR(s.SCHOOLID)                                                            AS j_SchoolCode
	,TRIM(TRANSLATE(s.HOME_ROOM, '|' || CHR(9) || CHR(10) || CHR(13), '    '))                                          AS k_Homeroom
	,CAST(NULL AS VARCHAR2(1))                                                      AS l_ElementarySchoolCode
	,CAST(NULL AS VARCHAR2(1))                                                      AS m_CommunityHours
	,CAST(NULL AS VARCHAR2(1))                                                      AS n_LiteracyTest
	,CAST(NULL AS VARCHAR2(1))                                                      AS o_Diploma
	,TRIM(TRANSLATE(scf.PSCORE_LEGAL_FIRST_NAME, '|' || CHR(9) || CHR(10) || CHR(13), '    '))                          AS p_LegalName
	,CASE WHEN NVL(s.NEXT_SCHOOL, 0) <> 0 THEN TO_CHAR(s.NEXT_SCHOOL) END           AS q_PreRegSchoolCode
FROM STUDENTS s
LEFT JOIN cfg ON 1=1
LEFT JOIN STUDENTCOREFIELDS scf ON scf.STUDENTSDCID = s.DCID
	AND cfg.include_legal_name = 1
LEFT JOIN STUDENTS sm ON sm.ID = s.ID
	AND cfg.append_middle_name = 1
WHERE s.GRADE_LEVEL >= cfg.min_student_grade
	AND s.ENROLL_STATUS IN (0, -1)
	AND (cfg.school_ids IS NULL OR INSTR(',' || REPLACE(cfg.school_ids, ' ', '') || ',', ',' || s.SCHOOLID || ',') > 0)
ORDER BY s.SCHOOLID, s.STUDENT_NUMBER
