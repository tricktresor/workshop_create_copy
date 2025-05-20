REPORT zt9r_zworkshop_create_copy_obj.


*--------------------------------*
* FUNKTIONIERT NOCH NICHT:
*--------------------------------*
* - Paket wird nicht in TR aufgenommen
* - TR wird ohne Aufgabe angelegt.

CONSTANTS c_target   TYPE tr_target VALUE 'ZINW'.

DATA gs_package_data TYPE scompkdtln.
DATA gv_trkorr       TYPE trkorr.
DATA gv_ptext        TYPE as4text.
DATA gv_package      TYPE devclass.


SELECTION-SCREEN BEGIN OF BLOCK inf WITH FRAME TITLE TEXT-inf.
  SELECTION-SCREEN COMMENT /1(70) TEXT-i01.
  SELECTION-SCREEN COMMENT /1(70) TEXT-i02.
  SELECTION-SCREEN COMMENT /1(70) TEXT-i03.
  SELECTION-SCREEN COMMENT /1(70) TEXT-i04.
  SELECTION-SCREEN COMMENT /1(70) TEXT-i05.
  SELECTION-SCREEN COMMENT /1(70) TEXT-i06.
SELECTION-SCREEN END OF BLOCK inf.

SELECTION-SCREEN BEGIN OF BLOCK kor WITH FRAME TITLE TEXT-kor.
  PARAMETERS p_trkorr  TYPE trkorr.
SELECTION-SCREEN END OF BLOCK kor.

SELECTION-SCREEN BEGIN OF BLOCK par WITH FRAME TITLE TEXT-par.
  PARAMETERS p_user    TYPE syuname     OBLIGATORY DEFAULT sy-uname.
  PARAMETERS p_wskey   TYPE c LENGTH 10 OBLIGATORY DEFAULT 'WS_ATC'.
  PARAMETERS p_wstxt   TYPE as4text     OBLIGATORY DEFAULT 'ATC-Workshop'.
SELECTION-SCREEN END OF BLOCK par.

SELECTION-SCREEN BEGIN OF BLOCK cpy WITH FRAME TITLE TEXT-cpy.
  SELECTION-SCREEN COMMENT /1(70) TEXT-i11.
  PARAMETERS p_cpyrep AS CHECKBOX DEFAULT space.
  PARAMETERS p_report  TYPE program     DEFAULT 'Z_DEMO_CODE_QUALITY_00'.
  PARAMETERS p_cpycls AS CHECKBOX DEFAULT space.
  PARAMETERS p_classn  TYPE seoclskey   DEFAULT 'ZCL_CHECK_DATE_00'.
SELECTION-SCREEN END OF BLOCK cpy.

SELECTION-SCREEN BEGIN OF BLOCK nte WITH FRAME TITLE TEXT-nte.
  PARAMETERS p_note01 TYPE string LOWER CASE.
  PARAMETERS p_note02 TYPE string LOWER CASE.
  PARAMETERS p_note03 TYPE string LOWER CASE.
  PARAMETERS p_note04 TYPE string LOWER CASE.
SELECTION-SCREEN END OF BLOCK nte.

INITIALIZATION.

  gv_package  = |Z{ p_wskey }_{ p_user }|.
  gv_ptext    = |{ p_wstxt } { p_user }|.

AT SELECTION-SCREEN.
  IF p_cpycls = abap_true AND p_classn IS INITIAL.
    SET CURSOR FIELD 'P_CLASSN'.
    MESSAGE 'Zu kopierende Klasse eingeben!' TYPE 'E'.
  ENDIF.
  IF p_cpyrep = abap_true AND p_report IS INITIAL.
    SET CURSOR FIELD 'P_REPORT'.
    MESSAGE 'Zu kopierenden Report eingeben!' TYPE 'E'.
  ENDIF.

START-OF-SELECTION.

  IF p_trkorr IS INITIAL.
    PERFORM create_transport_request.
  ELSE.
    gv_trkorr = p_trkorr.
  ENDIF.

  PERFORM create_package.
  PERFORM copy_program.
  PERFORM copy_class.

  COMMIT WORK.

FORM create_transport_request.
  CALL FUNCTION 'TR_EXT_CREATE_REQUEST'
    EXPORTING
      iv_request_type = 'K'
      iv_target       = c_target
      iv_author       = p_user
      iv_text         = p_wstxt
    IMPORTING
      es_req_id       = gv_trkorr.
  WRITE: / 'Transportauftrag', gv_trkorr, 'wurde angelegt'.
ENDFORM.

FORM create_package.

  SELECT SINGLE devclass FROM tdevc INTO @DATA(lv_devclass)
  WHERE devclass = @gv_package.
  IF sy-subrc  = 0.
    WRITE: / 'Paket', gv_package, 'ist vorhanden'.
    RETURN.
  ENDIF.

  gs_package_data = VALUE #(
    devclass  = gv_package
    ctext     = gv_ptext
    language  = sy-langu
    as4user   = p_user
    korrflag  = abap_true
    dlvunit   = 'HOME'
    pdevclass = c_target
    ).

  cl_package_factory=>create_new_package(
    EXPORTING
      i_reuse_deleted_object       = abap_true
      i_suppress_dialog            = abap_true
      i_suppress_access_permission = abap_false
    IMPORTING
      e_package                    = DATA(lo_package)
    CHANGING
      c_package_data               = gs_package_data
    EXCEPTIONS
      object_already_existing      = 1
      object_just_created          = 2
      not_authorized               = 3
      wrong_name_prefix            = 4
      undefined_name               = 5
      reserved_local_name          = 6
      invalid_package_name         = 7
      short_text_missing           = 8
      software_component_invalid   = 9
      layer_invalid                = 10
      author_not_existing          = 11
      component_not_existing       = 12
      component_missing            = 13
      prefix_in_use                = 14
      unexpected_error             = 15
      intern_err                   = 16
      no_access                    = 17
      invalid_translation_depth    = 18
      wrong_mainpack_value         = 19
      superpackage_invalid         = 20
      error_in_cts_checks          = 21
      OTHERS                       = 22 ).
  IF sy-subrc > 0.
    MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
      WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
  ELSE.
    lo_package->save(
      EXPORTING
        i_suppress_corr_insert = abap_true
        i_suppress_dialog      = abap_true
        i_transport_request    = gv_trkorr
      EXCEPTIONS
        object_not_changeable  = 1
        cancelled_in_corr      = 2
        permission_failure     = 3
        unexpected_error       = 4 ).
    IF sy-subrc = 0.
      WRITE: / 'Paket', gs_package_data-devclass, 'wurde angelegt.'.
    ENDIF.
  ENDIF.

ENDFORM.

FORM copy_program.

  IF p_cpyrep IS INITIAL.
    RETURN.
  ENDIF.

  DATA(gv_copy_report) = p_report.
  REPLACE '00' WITH sy-uname INTO gv_copy_report.

  SELECT SINGLE * FROM trdir INTO @DATA(ls_trdir)
  WHERE name = @gv_copy_report.
  IF sy-subrc = 0.
    WRITE: / 'Report', gv_copy_report, 'ist vorhanden'.
    RETURN.
  ENDIF.

  CALL FUNCTION 'RS_COPY_PROGRAM'
    EXPORTING
      corrnumber         = gv_trkorr
      devclass           = gs_package_data-devclass
      program            = gv_copy_report
      source_program     = p_report
      suppress_checks    = abap_true
      suppress_popup     = abap_true
      with_cua           = abap_true
      with_documentation = abap_true
      with_dynpro        = abap_true
      with_includes      = abap_true
      with_textpool      = abap_true
      with_variants      = abap_true
      generated          = abap_false
    EXCEPTIONS
      enqueue_lock       = 1
      object_not_found   = 2
      permission_failure = 3
      reject_copy        = 4
      OTHERS             = 5.
  IF sy-subrc <> 0.
    MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
      WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
  ENDIF.

ENDFORM.

FORM copy_class.

  DATA gv_newcls TYPE seoclskey.

  IF p_cpycls IS INITIAL.
    RETURN.
  ENDIF.

  gv_newcls = p_classn.
  REPLACE '00' WITH sy-uname INTO gv_newcls.

  TRY.
      DATA(lo_class) = NEW cl_oo_class( CONV #( gv_newcls ) ).
    CATCH cx_class_not_existent.
  ENDTRY.

  CALL FUNCTION 'SEO_CLASS_COPY'
    EXPORTING
      clskey        = p_classn
      new_clskey    = gv_newcls
      save          = abap_true
      suppress_corr = abap_true
    CHANGING
      devclass      = gs_package_data-devclass
      corrnr        = gv_trkorr
    EXCEPTIONS
      not_existing  = 1
      deleted       = 2
      is_interface  = 3
      not_copied    = 4
      db_error      = 5
      no_access     = 6
      OTHERS        = 7.
  IF sy-subrc = 0.
    WRITE: / p_classn, 'auf', gv_newcls, 'kopiert'.
    CALL FUNCTION 'SEO_CLASS_ACTIVATE'
      EXPORTING
        clskeys       = gv_newcls
      EXCEPTIONS
        not_specified = 1
        not_existing  = 2
        inconsistent  = 3
        OTHERS        = 4.
    IF sy-subrc = 0.
      WRITE: 'und aktiviert'.
    ELSE.
      WRITE: 'aber nicht aktiviert...'.
    ENDIF.
  ENDIF.

ENDFORM.
