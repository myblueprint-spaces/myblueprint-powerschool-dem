-- shsmrecord.sql - test copy of the SQL in Ontario/queries_root/ca.myblueprint.dem.shsmrecord.named_queries.xml (plugin version 1.2.1)
-- Run in a SQL tool (e.g. DBeaver/SQL Developer) against the PowerSchool database.
-- Edits here do NOT change the plugin; copy any changes back into the CDATA block (without these comment lines).

WITH cfg AS (
	SELECT
		''                             AS school_ids
		,'%SHSM%'                      AS program_name_pattern
		,1                             AS exclude_brd_res_9
		,0                             AS exclude_future_entries
		,'%SHSM'                       AS cert_group_pattern
	FROM dual
)
SELECT DISTINCT
	TO_CHAR(st.STUDENT_NUMBER)                                                     AS a_StudentID
	,'1'                                                                           AS b_RecordType
	,TO_CHAR(sc.DATE_COMPLETED, 'YYYY-MM-DD')                                      AS c_DateCompleted
	,TRIM(TRANSLATE(pcc.DESCRIPTION, '|' || CHR(9) || CHR(10) || CHR(13), '    ')) AS d_Name
	,pcc.CODE                                                                      AS e_CertificationID
	,CAST(NULL AS VARCHAR2(1))                                                     AS f_CLA
	,CAST(NULL AS VARCHAR2(1))                                                     AS g_Comments
	,TO_CHAR(sc.CERTIFICATION_HOURS)                                               AS h_Hours
	,TO_CHAR(st.SCHOOLID)                                                          AS i_SchoolCode
FROM STUDENTS st
LEFT JOIN cfg ON 1=1
INNER JOIN S_ON_STU_SHSM_CERT_C sc ON sc.STUDENTSDCID = st.DCID
INNER JOIN PS_COMMON_CODE pcc ON pcc.CODE = sc.CERTTYPE
	AND pcc.PS_GROUP LIKE cfg.cert_group_pattern
LEFT JOIN S_ON_STU_X x ON x.STUDENTSDCID = st.DCID
WHERE st.ENROLL_STATUS IN (0, -1)
	AND (cfg.school_ids IS NULL OR INSTR(',' || REPLACE(cfg.school_ids, ' ', '') || ',', ',' || st.SCHOOLID || ',') > 0)
	AND (cfg.exclude_brd_res_9 = 0 OR NVL(TO_CHAR(x.BRD_RES_STATUS), 'x') <> '9')
	AND (cfg.exclude_future_entries = 0 OR st.ENTRYDATE <= SYSDATE)
	AND EXISTS (
		SELECT 1
		FROM SPENROLLMENTS sp
		INNER JOIN GEN g ON g.ID = sp.PROGRAMID
			AND g.CAT = 'specprog'
			AND g.NAME LIKE cfg.program_name_pattern
		LEFT JOIN S_ON_SEN_X spx ON spx.SPENROLLMENTSDCID = sp.DCID
		WHERE sp.STUDENTID = st.ID
			AND (sp.EXIT_DATE IS NULL
				OR sp.EXIT_DATE = TO_DATE('1900-01-01', 'YYYY-MM-DD')
				OR sp.EXIT_DATE > SYSDATE
				OR (spx.SHSM_PROGRAM_DATE IS NOT NULL AND spx.SHSM_PROGRAM_DATE <> TO_DATE('1900-01-01', 'YYYY-MM-DD')))
	)
ORDER BY a_StudentID, c_DateCompleted
