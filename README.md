# myBlueprint Data Exports for PowerSchool (Data Export Manager)

An example PowerSchool plugin that adds PowerQueries for producing the myBlueprint SIS files from
**Data Export Manager (DEM)**. It does not use OAuth or the PowerSchool API. Exports run as the PowerSchool user who
sets them up, and DEM can send the files to myBlueprint on a schedule.

**Setup guide (DEM and SFTP transfer):**
[myBlueprint Data Exports - PowerSchool DEM setup](https://docs.google.com/document/d/18lTHRn_iNJJwHYWzBuXeW8FFaLWz-ElKBGV_XDvz1TU/edit?usp=sharing)

## Which folder to use

| Folder | For | PowerQueries |
|---|---|---|
| `Ontario/` | Ontario school boards | Student, StudentCourses, CourseMaster, SHSMStatus, SHSMRecord, ConEdSections |
| `Alberta/` | Alberta school divisions | Student, StudentCourses, CourseMaster |
| `Manitoba/` | Manitoba school divisions | Student, StudentCourses, CourseMaster |
| `SQL Test Scripts/` | Testing edits in a SQL tool (not part of the plugin) | Plain `.sql` copy of each query, one subfolder per variant |

| PowerQuery | myBlueprint file | Spec |
|---|---|---|
| `ca.myblueprint.dem.student` | `*.Student.txt` | Interface for SIS v1.25 §2.3 |
| `ca.myblueprint.dem.studentcourses` | `*.StudentCourses.txt` | Interface for SIS v1.25 §2.4 |
| `ca.myblueprint.dem.coursemaster` | `*.CourseMaster.txt` | Interface for SIS v1.25 §2.1 |
| `ca.myblueprint.dem.shsmstatus` (Ontario only) | `*.SHSMStatus.txt` | SHSM Integration v1.5 §1 |
| `ca.myblueprint.dem.shsmrecord` (Ontario only) | `*.SHSMRecord.txt` | SHSM Integration v1.5 §2 |
| `ca.myblueprint.dem.conedsections` (Ontario only) | `*.ConEdSections.txt` | None: Continuing Education sections for the ConEd course registration file |

The query names use the `ca.myblueprint.dem.*` namespace. That keeps them separate from the myBlueprint API plugin
(`ca.myblueprint.ep.integration.*`), so both plugins can be installed during a migration.

## Why the district installs this as its own plugin

myBlueprint doesn't publish this plugin. It is an example that each district installs and maintains as its **own**
plugin. That is why `plugin.xml` ships with placeholder publisher details. Districts that need the API integration
should keep using the myBlueprint API plugin.

## Process

1. **Download your province's plugin.** Each release on this repository's **Releases** page has a ready-built zip
   per province (`myBlueprintDataExport-Ontario-<version>.zip`, `-Alberta-`, `-Manitoba-`). Unzip it to edit the
   settings, or take the contents of your province's folder here (`plugin.xml`, `queries_root/` and
   `permissions_root/`). For other provinces, contact myBlueprint first. `Alberta/` is the closest starting point,
   but the course code and grade rules are Alberta-specific.
2. **Review the configuration blocks with myBlueprint.** Work through the settings in section 1 below with
   myBlueprint support (support@myblueprint.ca) or your technical implementation contact.
3. **Set the publisher in `plugin.xml`.** Replace `District Name` with your district's name and
   `replacewithyouremail@district.com` with your own contact email:

   ```xml
   <plugin xmlns="http://plugin.powerschool.pearson.com" name="myBlueprint Data Exports" version="1.2.1">
   	<publisher name="Example School District">
   		<contact email="sis.admin@example.org" />
   	</publisher>
   </plugin>
   ```

4. **Install and enable** the plugin (section 2), then **set up Data Export Manager** (section 3 and the setup guide).

## 1. Customize (before installing)

Each query's SQL opens with a `cfg` block holding its settings. The `DISTRICT SETTINGS` comment just above the
`<sql>` element explains each one. PowerQueries can't share settings, so a setting
that appears in more than one query has to be changed in every query that uses it.

| Setting | Queries | Default | myBlueprint API setting it replaces |
|---|---|---|---|
| `school_ids` | all except ConEdSections | `''` (all schools) | School integration ids |
| `coned_school_ids` | ConEdSections (Ontario) | `''` (**required**: no rows until set) | (new; the Continuing Education schools) |
| `min_student_grade` | Student, StudentCourses | `7` | PsApiMinStudentGrade |
| `min_course_grade` | StudentCourses | `8` | PsApiMinCourseGrade |
| `store_codes` | StudentCourses | `'F1,S1,S2,Y1'` (**review this**) | PsApiStoredCodes |
| `accept_exclude_from_gpa` | StudentCourses | `1` | PowerSchoolAcceptExcludeFromGpa |
| `include_legal_name` | Student | `0` | (new; sends the legal first name in LegalName) |
| `append_middle_name` | Student | `0` | PsApiAppendMiddleName |
| `powerscheduler_school_ids` | CourseMaster | `''` (none) | PsApiSchoolsUsingPowerScheduler |
| `hs_courses_only` | CourseMaster, StudentCourses (Alberta, Manitoba) | `1` | (new; leaves out junior high courses, see section 4) |
| `program_name_pattern`, `exclude_brd_res_9`, `exclude_future_entries` | SHSMStatus, SHSMRecord (Ontario) | `'%SHSM%'`, `1`, `0` | (from the sample scripts) |
| `cert_group_pattern` | SHSMRecord (Ontario) | `'%SHSM'` | (from the sample scripts) |
| Sector mapping (`b_Sector` / `c_SectorID` CASE lists) | SHSMStatus (Ontario) | Matches on program name. Keep both lists identical | (sample used hard-coded GEN ids) |

**School lists** go between the single quotes as one comma-separated value, with nothing else changed:

```sql
'97209,141518,910872'           AS school_ids      -- correct
''                              AS school_ids      -- all schools
CAST(97209,141518 AS ...)       AS school_ids      -- wrong (ORA-00905: missing keyword)
97209,141518                    AS school_ids      -- wrong
```

Make the same change in every query that has the setting. A syntax mistake in any query makes PowerSchool refuse to
enable the plugin (*"can't parse SQL"*). Paste the edited SQL into a SQL tool and run it first to check.
`SQL Test Scripts/` has a plain `.sql` copy of each query for this. Those copies don't affect the plugin, so copy any
changes back into the matching `queries_root` file.

**Course code mapping.** The `codes` block in StudentCourses and CourseMaster replaces the
PsApiCustomCourseCodeFormat and PsApiCustomAltCourseCodeFormat API settings. Change both queries the same way.
Each folder ships with its province's usual mapping:

| Folder | CourseCode | AltCourseCode | API setting equivalent |
|---|---|---|---|
| `Ontario/` | Course number | Blank (the `alt_course_number` field is usually a 5-character copy of the code, and myBlueprint identifies Ontario courses by CourseCode alone) | `{course_number}` / blank |
| `Alberta/` | Course number (e.g. `ELA1105`) | `alt_course_number` custom field | `{course_number}` / `{alt_course_number}` |
| `Manitoba/` | `alt_course_number` + `-` + `COURSES.CODE` (e.g. `0001-40S`), or the course number when `alt_course_number` is blank | Course number | `{alt_course_number}[-&{code}]` / `{course_number}` |

If your current API import uses a different mapping, change the `codes` block to match it before the first run.
myBlueprint matches existing courses and transcripts on CourseCode (plus AltCourseCode outside Ontario), so a
different mapping creates new courses instead of updating the existing ones. Leave CourseID blank for the same
reason: the API import never set it, and once it is set myBlueprint matches on it alone.

**Versions.** The example is at `1.2.1`. After any change, raise `version` in `plugin.xml`, re-zip the plugin and
reinstall it. If you don't change the version, PowerSchool rejects the upload as a version conflict, and you have to
delete the installed plugin first.

**Keep the plugin `name`, `<publisher name>` and contact the same between versions.** Set the publisher once (see
Process, step 3) and keep it in every later version. PowerSchool only accepts an update whose name and publisher match
the installed plugin exactly. Otherwise it fails with *"The plugin name or publisher of this plugin does not match the
plugin name or publisher of the currently installed plugin"*. To change them, delete the installed plugin and install
the new one fresh. Deleting removes the plugin's queries, so the DEM templates and schedules may need to be set up
again.

**Don't put comments inside the SQL.** `/* … */` or `--` comments inside the SQL make the plugin fail when it is
enabled, showing *"PowerQuery … can't parse SQL"* for each query, followed by *"Permission mapping refers to unknown
PowerQuery"* for its permission file. Put notes in XML comments (`<!-- … -->`) outside the `<![CDATA[ … ]]>` block
instead. The queries also deliberately stick to SQL patterns that are known to work in PowerQueries, such as
`LEFT JOIN cfg ON 1=1`, `TO_DATE(...)` and explicit column lists.

**Keep the final SELECT reading real tables.** PowerSchool traces every output column back to a table. When output
columns are selected from `WITH` blocks that also join the settings block, PowerSchool refuses the query with
*"cannot determine table name of column student_number"*. The Student and SHSMStatus queries therefore select directly
from PowerSchool tables, and the `cfg` settings block is only used in `ON` and `WHERE` conditions. A subquery in the
FROM clause fails too, with *"PowerQuery ?? invalid XML: Unexpected character 'c' … in prolog"*. Use subqueries in the
SELECT list (e.g. community hours), or `IN (...)` / `NOT EXISTS (...)` in WHERE. Keep this pattern if you edit them.

**Don't add tables or plugin.xml elements without testing.** PowerSchool checks every table a query uses when the
plugin is **enabled**, not when it is installed. A table no user type may read (for example `PREFS`) stops the plugin
from enabling, with *"query defines one or more tables that aren't allowed for any user type, but user type ADMIN
is required"*. `plugin.xml` is checked against PowerSchool's schema at install time, so an unexpected element
(e.g. `<extension>`) fails with a `SAXParseException`.

## 2. Install

1. Zip `plugin.xml`, `queries_root/` and `permissions_root/` so they sit at the **root** of the zip, not inside a
   folder. Paths inside the zip must use forward slashes. The Windows PowerShell 5.1 `Compress-Archive` command
   writes backslashes, so use 7-Zip or Windows Explorer's "Send to > Compressed folder" instead.
2. In PowerSchool, open **System > System Settings > Plugin Management Configuration**, click **Install** and
   upload the zip.
3. **Enable** the plugin. This is when the query validation runs (see above), so screenshot any error and send it
   to myBlueprint.
4. By default, any role that can open `/admin/home.html` can run the queries. To restrict access, edit
   `permissions_root/*.xml` before installing.

There is no separate "Named Queries" page to check. The queries only appear in Data Export Manager.

## 3. Set up Data Export Manager

The [setup guide](https://docs.google.com/document/d/18lTHRn_iNJJwHYWzBuXeW8FFaLWz-ElKBGV_XDvz1TU/edit?usp=sharing)
covers DEM and the SFTP transfer step by step. In short:

1. Switch to the **District Office** so the export covers every school. The `school_ids` setting then narrows the
   list if you need it to. If you run the export from inside one school, PowerSchool may limit it to that school.
2. Open **System > Data and Reporting > Exports > Data Export Manager**.
3. Under **Select Category**, look in **Additional Data Sets** or **Uncategorized** for the
   `ca.myblueprint.dem.*` queries. (They are not under a "PowerQueries" or "Named Queries" heading.) Pick the
   query itself, not one of DEM's built-in templates with a similar name.
4. Create one export per file with these settings.

* **Columns.** Select all of them and keep the order the export shows. The `a_`, `b_` … prefixes keep the
  columns in file order. myBlueprint reads fields by position, so the order must not change.
* **Output options**
  * Field delimiter: **Pipe (`|`)**
  * Column headers: **off**. The SHSM files must have no header, and leaving it off on the other files is safest.
    If headers are left on, DEM writes its own labels (e.g. `STUDENTS.a_StudentID`) rather than clean field names,
    and the "Labels Used on Export" fields would have to be edited by hand.
  * Surround values in quotes: **none**. The queries replace any `|`, tab or newline in text values with a space.
  * Line endings: standard **CRLF** or **LF**.
  * Character set: **UTF-8** for all files. (The SHSM spec lists Windows-1252, but myBlueprint detects the
    encoding and converts every file to UTF-8 on import, and UTF-8 keeps characters like dashes and accents intact.)
  * File name: anything that ends with the file type, using the **exact capitalization** shown, e.g.
    `district.Student.txt`, `district.StudentCourses.txt`, `district.CourseMaster.txt`,
    `district.SHSMStatus.txt`, `district.SHSMRecord.txt`, `district.ConEdSections.txt`.
* **Test manually first.** Run each export once by hand, upload the files to the myBlueprint SFTP folder (or send
  them to myBlueprint), and wait for confirmation before scheduling.
* **Schedule.** Save each export as a **template**, then schedule the template to send to the myBlueprint SFTP
  folder through **Remote Connection Manager**. This works for PowerSchool-hosted (cloud) districts too, with no
  local server or script. myBlueprint takes the files individually, so there's no need to zip them. Schedule them
  all to finish before the import window agreed with myBlueprint.
* **After setting up the schedule, check the first scheduled files**, not just the manual run. Scheduled DEM jobs
  have been seen running built-in DEM templates instead of the plugin queries, with output that didn't match the
  manual run. Check that each scheduled job points at the `ca.myblueprint.dem.*` query.
* **Year-end rollover.** The queries work out the school year from today's date. In September they switch to the
  new year, so finish the PowerSchool rollover before then. If you roll over in summer, re-run the exports
  afterwards and let myBlueprint know.

## 4. Differences between the province folders

The folders are otherwise identical. Any change to shared logic (settings, filters, de-duplication, column order)
goes into **every** folder and every `SQL Test Scripts` subfolder in the same commit, and all `plugin.xml` versions go
up together.

| | Ontario | Alberta | Manitoba |
|---|---|---|---|
| SHSMStatus and SHSMRecord queries | Yes (`GEN`, `SPENROLLMENTS`, `S_ON_SEN_X`, `S_ON_STU_SHSM_CERT_C`, `PS_COMMON_CODE`) | Not included | Not included |
| ConEdSections query | Yes (`SECTIONS`, `SCHOOLS`, `TERMS`) | Not included | Not included |
| Student CommunityHours | `S_ON_STU_COMMUNITY_HOURS_C` | Blank | Blank |
| Student LiteracyTest (OSSLT) | `PSSR_ON_COMMON.LITERACYREQUIREMENT()` | Blank | Blank |
| StudentCourses FinalMark | `STOREDGRADES.GRADE` | `AB_FINAL_MARK`, else `GRADE` | `STOREDGRADES.GRADE` |
| StudentCourses DateCompleted | `S_ON_SGR_X.CREDIT_DATE`, else term last day | Term last day | Term last day |
| StudentCourses PLE handling | `PLE%` course numbers kept apart, `STOREDGRADES.CREDIT_TYPE` as SubstituteID | None; SubstituteID blank | None; SubstituteID blank |
| Course code mapping | See section 1 | See section 1 | See section 1 |
| CourseMaster Grade | 4th character of the code: 1-4 → 9-12, otherwise 9 | 4th character of the code: 1/2/3 → 10/11/12, otherwise blank (myBlueprint uses 10) | First character of `COURSES.CODE`: 1-4 → 9-12, otherwise blank (myBlueprint uses 9) |
| `hs_courses_only` (junior high filter) | Not included | Keeps courses whose number has 1, 2 or 3 as the 4th character (senior high codes such as `ELA1105` or `LDC3164`). Other courses are kept in CourseMaster when they carry credit, and in StudentCourses from grade 10 up | Keeps courses whose `CODE` starts with 1-4 (`10F` … `40S`). Other courses are kept in CourseMaster when they carry credit, and in StudentCourses from grade 9 up |

`diff -r -w Alberta Manitoba` should only show the Alberta and Manitoba differences above. `diff -r -w Ontario Alberta`
shows those plus the Ontario ones.

## 5. Known gaps and checks for the first run

* `ps_customfields.getcf('Courses', …, 'alt_course_number')` returns NULL in districts that don't have that
  legacy custom field. That is harmless.
* Run each export once by hand and compare it with the current API import for one school before you schedule it.

**Ontario**
* **Pathway** (required in SHSMStatus) has no standard PowerSchool source and is exported blank.
* Field names come from the API plugin and board scripts: `S_ON_SEN_X.SHSM_*`, `SPC_*`, `S_ON_STU_SHSM_CERT_C`,
  `BRD_RES_STATUS`. Boards with different Ontario extension versions may need to adjust them. The SHSM date fields
  are assumed to be DATE columns.
* **Tables not yet proven in a DEM plugin.** The SHSM queries read `GEN`, `SPENROLLMENTS`, `S_ON_SEN_X`,
  `S_ON_STU_SHSM_CERT_C` and `PS_COMMON_CODE`, which the API plugin didn't use. If enabling fails with the "tables
  that aren't allowed for any user type" error, one of these is the likely cause. Send myBlueprint the screenshot
  and your PowerSchool version (**System > System Information**).
* **ConEdSections** exports nothing until `coned_school_ids` lists the Continuing Education schools. It takes
  sections whose term is in the current or next school year, so a summer session registered in spring falls in the
  current year and a fall night school registered in summer in the next.

**Alberta**
* **Junior high filter.** `hs_courses_only` assumes junior high courses either have no Alberta senior high code or
  carry no credit. Check the first CourseMaster file for junior high courses that slipped through (for example, ones
  with credit hours set) and for placeholder courses you need that were dropped. Set it to `0` to send every course.
* **CTS.** The myBlueprint API plugin also sent the `AB_CTS_Indicator` course custom field. CourseMaster.txt has no
  column for it, so these queries don't send it. If your division uses CTS header courses, ask myBlueprint which CTS
  setting to use with the file import.

**Manitoba**
* **Course codes.** CourseCode only matches the Manitoba ministry courses when `alt_course_number` holds the 4-digit
  subject number and `COURSES.CODE` holds the grade, credit and type (e.g. `40S`). Courses without
  `alt_course_number` are sent with their PowerSchool course number and won't match a ministry course.
* **French immersion** course codes (often marked with an `X`) haven't been checked yet. Send myBlueprint a sample
  if your division offers them.
