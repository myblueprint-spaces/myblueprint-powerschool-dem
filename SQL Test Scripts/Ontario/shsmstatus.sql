-- shsmstatus.sql - test copy of the SQL in Ontario/queries_root/ca.myblueprint.dem.shsmstatus.named_queries.xml (plugin version 1.2.0)
-- Run in a SQL tool (e.g. DBeaver/SQL Developer) against the PowerSchool database.
-- Edits here do NOT change the plugin; copy any changes back into the CDATA block (without these comment lines).

WITH cfg AS (
	SELECT
		''                             AS school_ids
		,'%SHSM%'                      AS program_name_pattern
		,1                             AS exclude_brd_res_9
		,0                             AS exclude_future_entries
	FROM dual
)
SELECT
	TO_CHAR(st.STUDENT_NUMBER)                               AS a_StudentID
	,CASE
		WHEN g.NAME LIKE '%Agricultur%' THEN 'Agriculture'
		WHEN g.NAME LIKE '%Arts%' THEN 'Arts and Culture'
		WHEN g.NAME LIKE '%Aviation%' THEN 'Aviation and Aerospace'
		WHEN g.NAME LIKE '%Business%' THEN 'Business'
		WHEN g.NAME LIKE '%Construction%' THEN 'Construction'
		WHEN g.NAME LIKE '%Energy%' THEN 'Energy'
		WHEN g.NAME LIKE '%Environment%' THEN 'The Environment'
		WHEN g.NAME LIKE '%Forestry%' THEN 'Forestry'
		WHEN g.NAME LIKE '%Health%' THEN 'Health and Wellness'
		WHEN g.NAME LIKE '%Horticult%' THEN 'Horticulture and Landscaping'
		WHEN g.NAME LIKE '%Hospitality%' THEN 'Hospitality and Tourism'
		WHEN g.NAME LIKE '%Information%' THEN 'Information and Communications Technology'
		WHEN g.NAME LIKE '%Justice%' THEN 'Justice, Community Safety, and Emergency Services'
		WHEN g.NAME LIKE '%Manufactur%' THEN 'Manufacturing'
		WHEN g.NAME LIKE '%Mining%' THEN 'Mining'
		WHEN g.NAME LIKE '%Non%Profit%' THEN 'NonProfit'
		WHEN g.NAME LIKE '%Sport%' THEN 'Sports'
		WHEN g.NAME LIKE '%Transport%' THEN 'Transportation'
		WHEN g.NAME LIKE '%Food%' THEN 'Food Processing'
	END                                                      AS b_Sector
	,CASE
		WHEN g.NAME LIKE '%Agricultur%' THEN '4'
		WHEN g.NAME LIKE '%Arts%' THEN '5'
		WHEN g.NAME LIKE '%Aviation%' THEN '6'
		WHEN g.NAME LIKE '%Business%' THEN '7'
		WHEN g.NAME LIKE '%Construction%' THEN '8'
		WHEN g.NAME LIKE '%Energy%' THEN '9'
		WHEN g.NAME LIKE '%Environment%' THEN '10'
		WHEN g.NAME LIKE '%Forestry%' THEN '11'
		WHEN g.NAME LIKE '%Health%' THEN '12'
		WHEN g.NAME LIKE '%Horticult%' THEN '13'
		WHEN g.NAME LIKE '%Hospitality%' THEN '14'
		WHEN g.NAME LIKE '%Information%' THEN '15'
		WHEN g.NAME LIKE '%Justice%' THEN '16'
		WHEN g.NAME LIKE '%Manufactur%' THEN '17'
		WHEN g.NAME LIKE '%Mining%' THEN '18'
		WHEN g.NAME LIKE '%Non%Profit%' THEN '19'
		WHEN g.NAME LIKE '%Sport%' THEN '20'
		WHEN g.NAME LIKE '%Transport%' THEN '21'
		WHEN g.NAME LIKE '%Food%' THEN '22'
	END                                                      AS c_SectorID
	,CAST(NULL AS VARCHAR2(1))                               AS d_Pathway
	,CASE WHEN xs.SHSM_PROGRAM_DATE IS NOT NULL AND xs.SHSM_PROGRAM_DATE <> TO_DATE('1900-01-01', 'YYYY-MM-DD') THEN 'C' ELSE 'E' END AS e_Status
	,TO_CHAR(sp.ENTER_DATE, 'YYYY-MM-DD')                    AS f_DateEnrolled
	,CASE WHEN xs.SHSM_PROGRAM_DATE <> TO_DATE('1900-01-01', 'YYYY-MM-DD') THEN TO_CHAR(xs.SHSM_PROGRAM_DATE, 'YYYY-MM-DD') END AS g_DateCompleted
	,CASE WHEN xs.SHSM_EXPERIENTIAL_DATE IS NULL OR xs.SHSM_EXPERIENTIAL_DATE = TO_DATE('1900-01-01', 'YYYY-MM-DD') THEN '0' ELSE '1' END AS h_ELA
	,CASE WHEN xs.SHSM_REACHAHEAD_DATE IS NULL OR xs.SHSM_REACHAHEAD_DATE = TO_DATE('1900-01-01', 'YYYY-MM-DD') THEN '0' ELSE '1' END AS i_ReachAhead
	,CASE WHEN xs.SHSM_SKILLDEV_DATE IS NULL OR xs.SHSM_SKILLDEV_DATE = TO_DATE('1900-01-01', 'YYYY-MM-DD') THEN '0' ELSE '1' END AS j_OSP
	,CAST(NULL AS VARCHAR2(1))                               AS k_CLA
	,'0'                                                     AS l_IEP
	,TO_CHAR(st.SCHOOLID)                                    AS m_SchoolCode
	,TO_CHAR(NVL(xs.SPC_CODING, 0))                          AS n_SpccCoding
	,TO_CHAR(NVL(xs.SPC_INNOVATION, 0))                      AS o_SpccInnovation
	,TO_CHAR(NVL(xs.SPC_MATHLIT, 0))                         AS p_SpccMathLit
FROM STUDENTS st
LEFT JOIN cfg ON 1=1
INNER JOIN SPENROLLMENTS sp ON sp.STUDENTID = st.ID
INNER JOIN GEN g ON g.ID = sp.PROGRAMID
	AND g.CAT = 'specprog'
	AND g.NAME LIKE cfg.program_name_pattern
LEFT JOIN S_ON_SEN_X xs ON xs.SPENROLLMENTSDCID = sp.DCID
LEFT JOIN S_ON_STU_X x ON x.STUDENTSDCID = st.DCID
WHERE st.ENROLL_STATUS IN (0, -1)
	AND (cfg.school_ids IS NULL OR INSTR(',' || REPLACE(cfg.school_ids, ' ', '') || ',', ',' || st.SCHOOLID || ',') > 0)
	AND (cfg.exclude_brd_res_9 = 0 OR NVL(TO_CHAR(x.BRD_RES_STATUS), 'x') <> '9')
	AND (cfg.exclude_future_entries = 0 OR st.ENTRYDATE <= SYSDATE)
	AND (sp.EXIT_DATE IS NULL
		OR sp.EXIT_DATE = TO_DATE('1900-01-01', 'YYYY-MM-DD')
		OR sp.EXIT_DATE > SYSDATE
		OR (xs.SHSM_PROGRAM_DATE IS NOT NULL AND xs.SHSM_PROGRAM_DATE <> TO_DATE('1900-01-01', 'YYYY-MM-DD')))
	AND NOT EXISTS (
		SELECT 1
		FROM SPENROLLMENTS sp3
		INNER JOIN STUDENTS st3 ON st3.ID = sp3.STUDENTID
		LEFT JOIN S_ON_SEN_X xs3 ON xs3.SPENROLLMENTSDCID = sp3.DCID
		WHERE st3.STUDENT_NUMBER = st.STUDENT_NUMBER
			AND sp3.PROGRAMID = sp.PROGRAMID
			AND sp3.DCID <> sp.DCID
			AND (sp3.EXIT_DATE IS NULL
				OR sp3.EXIT_DATE = TO_DATE('1900-01-01', 'YYYY-MM-DD')
				OR sp3.EXIT_DATE > SYSDATE
				OR (xs3.SHSM_PROGRAM_DATE IS NOT NULL AND xs3.SHSM_PROGRAM_DATE <> TO_DATE('1900-01-01', 'YYYY-MM-DD')))
			AND (
				CASE WHEN xs3.SHSM_PROGRAM_DATE IS NOT NULL AND xs3.SHSM_PROGRAM_DATE <> TO_DATE('1900-01-01', 'YYYY-MM-DD') THEN 1 ELSE 0 END > CASE WHEN xs.SHSM_PROGRAM_DATE IS NOT NULL AND xs.SHSM_PROGRAM_DATE <> TO_DATE('1900-01-01', 'YYYY-MM-DD') THEN 1 ELSE 0 END
				OR (CASE WHEN xs3.SHSM_PROGRAM_DATE IS NOT NULL AND xs3.SHSM_PROGRAM_DATE <> TO_DATE('1900-01-01', 'YYYY-MM-DD') THEN 1 ELSE 0 END = CASE WHEN xs.SHSM_PROGRAM_DATE IS NOT NULL AND xs.SHSM_PROGRAM_DATE <> TO_DATE('1900-01-01', 'YYYY-MM-DD') THEN 1 ELSE 0 END
					AND (NVL(sp3.ENTER_DATE, TO_DATE('1900-01-01', 'YYYY-MM-DD')) > NVL(sp.ENTER_DATE, TO_DATE('1900-01-01', 'YYYY-MM-DD'))
						OR (NVL(sp3.ENTER_DATE, TO_DATE('1900-01-01', 'YYYY-MM-DD')) = NVL(sp.ENTER_DATE, TO_DATE('1900-01-01', 'YYYY-MM-DD')) AND sp3.DCID > sp.DCID)))
			)
	)
ORDER BY st.STUDENT_NUMBER, c_SectorID
