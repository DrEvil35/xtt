class ZCL_XTT_SCOPE definition
  public
  final
  create private .

public section.

  types:
    BEGIN OF ts_pair,
        key TYPE string,
        val TYPE string,
      END OF ts_pair .
  types:
    tt_pair TYPE SORTED TABLE OF ts_pair WITH UNIQUE KEY key .
  types:
    BEGIN OF ts_scope,
        index    TYPE i,
        beg      TYPE i,
        end      TYPE i,
        sc_level TYPE i,
        field    TYPE string,
        t_pair   TYPE tt_pair,
      END OF ts_scope .
  types:
    tt_scope TYPE STANDARD TABLE OF ts_scope WITH DEFAULT KEY .

  data MT_SCOPE type TT_SCOPE read-only .

  class-methods GET_INSTANCE
    importing
      !IO_BLOCK type ref to ZCL_XTT_REPLACE_BLOCK
      !IV_FORCE type ABAP_BOOL
    exporting
      !EV_NEW type ABAP_BOOL
      !EO_INSTANCE type ref to ZCL_XTT_SCOPE .
  class-methods CLEAR_ALL .
  methods GET_SCOPES
    importing
      !IV_INDEX type I optional
      !IO_XTT type ref to ZCL_XTT
    exporting
      !EV_INLINE_TREE type ABAP_BOOL
    changing
      !CV_CONTENT type STRING .
  methods CALC_COND_MATCHES
    importing
      !IO_XTT type ref to ZCL_XTT
      !IV_TABIX type SYTABIX
      !IO_BLOCK type ref to ZCL_XTT_REPLACE_BLOCK
      !IV_INIT type ABAP_BOOL .
  methods IS_BY_COLUMN
    importing
      !IV_FIELD_NAME type CSEQUENCE
    returning
      value(RV_BY_COLUMN) type ABAP_BOOL .
  class-methods _GET_SCOPE_FIELD
    importing
      !IV_CONTENT type STRING
    changing
      !CS_SCOPE type TS_SCOPE
      !CV_WHOLE_FIELD type STRING .
protected section.
private section.

  types:
    BEGIN OF ts_instance,
      sc_id TYPE string,
      scope TYPE REF TO zcl_xtt_scope,
    END OF ts_instance .
  types:
    tt_instance TYPE SORTED TABLE OF ts_instance WITH UNIQUE KEY sc_id .
  types:
    BEGIN OF ts_extra_tab_opt,
        name      TYPE string, " Name of table 'R-T'
        direction TYPE string, " ;direction=column ?
        group     TYPE string, " ;group=BUKRS;WERKS or ;group=FILED-FILED_PAR
      END OF ts_extra_tab_opt .
  types:
    tt_extra_tab_opt TYPE SORTED TABLE OF ts_extra_tab_opt WITH UNIQUE KEY name .

  class-data MT_INSTANCE type TT_INSTANCE .
  data MO_BLOCK type ref to ZCL_XTT_REPLACE_BLOCK .
  data MT_EXTRA_TAB_OPT type TT_EXTRA_TAB_OPT .
  data MO_COND type ref to ZCL_XTT_COND .

  methods _GET_SCOPE
    importing
      !IV_OFFSET type I
      !IO_XTT type ref to ZCL_XTT
      !IV_CONTENT type STRING
    returning
      value(RR_SCOPE) type ref to TS_SCOPE .
  methods _INLINE_TREE
    importing
      !IO_XTT type ref to ZCL_XTT
      !IS_SCOPE type TS_SCOPE
    returning
      value(RV_OK) type ABAP_BOOL .
  methods _FILL_WITH_BLANKS
    importing
      !IS_SCOPE type TS_SCOPE
    changing
      !CV_CONTENT type STRING .
  methods _FILL_T_PAIR
    importing
      !IV_WHOLE_FIELD type STRING
      !IR_SCOPE type ref to TS_SCOPE .
  methods _IS_LEVEL_NORM
    importing
      !IR_SCOPE type ref to TS_SCOPE
    returning
      value(RV_OK) type ABAP_BOOL .
ENDCLASS.



CLASS ZCL_XTT_SCOPE IMPLEMENTATION.


METHOD calc_cond_matches.
  IF iv_init = abap_true.
    " Dynamic fileds
    DATA lt_cond_scope LIKE mt_scope.

    FIELD-SYMBOLS <ls_scope> LIKE LINE OF mt_scope.
    DATA lv_block_level TYPE i.
    lv_block_level = io_block->ms_ext-rb_level + 1.
    LOOP AT mt_scope ASSIGNING <ls_scope> WHERE sc_level = lv_block_level.

*      FIELD-SYMBOLS <ls_pair> LIKE LINE OF <ls_scope>-t_pair.
*      READ TABLE <ls_scope>-t_pair ASSIGNING <ls_pair>
*       WITH TABLE KEY key = 'type'.
*
*      DATA lv_type TYPE string.
*      IF sy-subrc = 0.
*        lv_type = <ls_pair>-val.
*      ELSE.
*        CLEAR lv_type.
*      ENDIF.
*
*      IF <ls_scope>-sc_level = lv_block_level.
*        CHECK lv_type <> zcl_xtt_replace_block=>mc_type-block.
*       ELSE. " lv_block_level skip already proccessed
*        CHECK lv_type = zcl_xtt_replace_block=>mc_type-block.
*      ENDIF.

      " Has dynamic conditions ?
      READ TABLE <ls_scope>-t_pair TRANSPORTING NO FIELDS
       WITH TABLE KEY key = 'cond'.
      CHECK sy-subrc  = 0.

      INSERT <ls_scope> INTO TABLE lt_cond_scope.
    ENDLOOP.

    " No need
    CHECK lt_cond_scope IS NOT INITIAL.
    CREATE OBJECT mo_cond
      EXPORTING
        io_xtt = io_xtt.
  ENDIF.

  " Delegate call
  CHECK mo_cond IS NOT INITIAL.
  mo_cond->calc_matches( io_xtt   = io_xtt
                         iv_tabix = iv_tabix
                         io_block = io_block
                         it_scope = lt_cond_scope ).
ENDMETHOD.


METHOD clear_all.
  CLEAR mt_instance.
ENDMETHOD.


METHOD get_instance.
  CLEAR: ev_new,
         eo_instance.

  DATA ls_instance TYPE ts_instance.
  DATA lr_instance TYPE REF TO ts_instance.

  READ TABLE mt_instance REFERENCE INTO lr_instance
   WITH TABLE KEY sc_id = io_block->ms_ext-rb_id.
  IF sy-subrc = 0.
    " Recreate
    IF iv_force = abap_true.
      DELETE mt_instance INDEX sy-tabix.
    ELSE.
      eo_instance = lr_instance->scope.
      RETURN.
    ENDIF.
  ENDIF.

  " Not initilized
  ev_new = abap_true.
  CREATE OBJECT eo_instance.
  eo_instance->mo_block = io_block.

  ls_instance-sc_id = io_block->ms_ext-rb_id.
  ls_instance-scope = eo_instance.
  INSERT ls_instance INTO TABLE mt_instance.
ENDMETHOD.


METHOD get_scopes.
  CLEAR ev_inline_tree.

  DATA lv_text_begin TYPE string.
  CONCATENATE '{' mo_block->ms_ext-name INTO lv_text_begin.

  DATA lt_find_res TYPE match_result_tab.
  FIND ALL OCCURRENCES OF lv_text_begin IN cv_content RESULTS lt_find_res.

**********************************************************************
  " Search from the last position. That's why 1 run only
  DATA lv_index TYPE i.
  lv_index = lines( lt_find_res ).
  WHILE lv_index > 0.
    " Read the next match
    FIELD-SYMBOLS <ls_find_res> LIKE LINE OF lt_find_res.
    READ TABLE lt_find_res ASSIGNING <ls_find_res> INDEX lv_index.
    lv_index = lv_index - 1.

    DATA lr_scope TYPE REF TO ts_scope.
    lr_scope = _get_scope( io_xtt     = io_xtt
                           iv_offset  = <ls_find_res>-offset
                           iv_content = cv_content ).
    CHECK lr_scope->end IS NOT INITIAL.

    " delete from template
    IF _inline_tree( io_xtt   = io_xtt
                     is_scope = lr_scope->* ) = abap_true.
      ev_inline_tree = abap_true.
      _fill_with_blanks( EXPORTING is_scope   = lr_scope->*
                         CHANGING  cv_content = cv_content ).
      CONTINUE.
    ENDIF.

    " Fill result
    lr_scope->index = iv_index.
    APPEND lr_scope->* TO mt_scope.
  ENDWHILE.
ENDMETHOD.


METHOD is_by_column.
  FIELD-SYMBOLS <ls_extra_tab_opt> LIKE LINE OF mt_extra_tab_opt.
  READ TABLE mt_extra_tab_opt ASSIGNING <ls_extra_tab_opt>
   WITH TABLE KEY name = iv_field_name.
  CHECK sy-subrc = 0 AND <ls_extra_tab_opt>-direction = 'column'.
  " By default by row
  rv_by_column = abap_true.
ENDMETHOD.


METHOD _fill_t_pair.
  DATA: lt_params TYPE stringtab.

  DATA l_whole_field LIKE iv_whole_field.
  l_whole_field = zcl_xtt_cond=>unescape( iv_whole_field ).
  SPLIT l_whole_field AT ';' INTO TABLE lt_params.

  " Always name of field in first part
  DATA: lv_param TYPE string, ls_pair TYPE ts_pair.
  DATA lv_next      TYPE i VALUE 0.
  DATA lv_curr_coef TYPE i VALUE 1.
  LOOP AT lt_params INTO lv_param FROM 2.
    SPLIT lv_param AT '=' INTO ls_pair-key ls_pair-val.

    CASE ls_pair-key .
      WHEN 'cond'. " +1 level
        lv_next = 1.
      WHEN 'type'. " 'cond' for current levele
        IF ls_pair-val = zcl_xtt_replace_block=>mc_type-block.
          lv_curr_coef = 0.
        ENDIF.
    ENDCASE.

    INSERT ls_pair INTO TABLE ir_scope->t_pair.
  ENDLOOP.

  " Change level
  ir_scope->sc_level  = ir_scope->sc_level + lv_next * lv_curr_coef.
ENDMETHOD.


METHOD _fill_with_blanks.
  DATA: lv_len TYPE i, lv_blanks TYPE string.

  lv_len    = is_scope-end - is_scope-beg + 1.
  lv_blanks = zcl_xtt_util=>repeat( val = ` `
                                    occ = lv_len ).
  REPLACE SECTION OFFSET is_scope-beg LENGTH lv_len OF cv_content WITH lv_blanks.
ENDMETHOD.


METHOD _get_scope.
  CREATE DATA rr_scope.

  " 1 try
  rr_scope->beg  = iv_offset.
  FIND FIRST OCCURRENCE OF '}'
       IN SECTION OFFSET rr_scope->beg OF iv_content
       MATCH OFFSET rr_scope->end.
  CHECK sy-subrc = 0.

  " Read tech name
  DATA: l_whole_field TYPE string, l_beg TYPE i, l_cnt TYPE i.
  l_beg         = rr_scope->beg + 1.
  l_cnt         = rr_scope->end - rr_scope->beg - 1.
  l_whole_field = iv_content+l_beg(l_cnt).

  " Get field bounds till `;` or `}`
  DATA lv_end TYPE i.
  FIND FIRST OCCURRENCE OF ';' IN SECTION OFFSET rr_scope->beg OF iv_content
       MATCH OFFSET lv_end.
  IF sy-subrc <> 0 OR lv_end > rr_scope->end.
    lv_end = rr_scope->end.
  ENDIF.

  " New name
  l_cnt          = lv_end - rr_scope->beg - 1.
  rr_scope->field = iv_content+l_beg(l_cnt).

  " Ingone option of grandchildren {R-T-FIELD}
  IF io_xtt->mv_skip_tags <> abap_true.
    FIND ALL OCCURRENCES OF '-' IN rr_scope->field MATCH COUNT rr_scope->sc_level.
    CHECK _is_level_norm( rr_scope ) = abap_true.
  ENDIF.

  " Make unique name
  IF mo_block->ms_ext-name = rr_scope->field.
    rr_scope->field = l_whole_field.
  ENDIF.

  " Extend name
  _get_scope_field( EXPORTING iv_content     = iv_content
                    CHANGING  cs_scope       = rr_scope->*
                              cv_whole_field = l_whole_field ).

  " Delete all rubbish between
  IF io_xtt->mv_skip_tags = abap_true.
    REPLACE ALL OCCURRENCES OF REGEX '<[^\>]+>' IN l_whole_field WITH ''.
    " Add warning
    IF sy-subrc = 0.
      l_cnt = l_cnt - strlen( l_whole_field ).
      MESSAGE w013(zsy_xtt) WITH l_cnt l_whole_field INTO sy-msgli.
      io_xtt->add_log_message( iv_syst = abap_true ).

      " Also clear the name
      REPLACE ALL OCCURRENCES OF REGEX '<[^\>]+>' IN rr_scope->field WITH ''.
    ENDIF.

    " Ingone option of grandchildren {R-T-FIELD}
    DATA lv_name TYPE string.
    lv_name = rr_scope->field.
    FIND FIRST OCCURRENCE OF ';' IN lv_name MATCH OFFSET lv_end.
    IF sy-subrc = 0.
      lv_name = lv_name(lv_end).
    ENDIF.

    FIND ALL OCCURRENCES OF '-' IN lv_name MATCH COUNT rr_scope->sc_level.
    CHECK _is_level_norm( rr_scope ) = abap_true.
  ENDIF.

  " All field options
  _fill_t_pair( iv_whole_field = l_whole_field
                ir_scope       = rr_scope ).

  _is_level_norm( rr_scope ).
ENDMETHOD.


METHOD _get_scope_field.
  CHECK cs_scope-field CS '{'.

  DATA l_beg  TYPE i.
  DATA lv_pos TYPE i.
  l_beg  = cs_scope-beg + 1.
  lv_pos = l_beg + sy-fdpos.

  " Max length
  DATA lv_content_len TYPE i.
  lv_content_len = strlen( iv_content ).

  " Find pairs of  {R;cond= {{}}    } <--here
  DATA lv_br_count  TYPE i VALUE 1.
  WHILE lv_br_count <> - 1.
    lv_pos = lv_pos + 1.
    IF lv_pos >= lv_content_len OR sy-index > 255.
      MESSAGE e024(zsy_xtt) WITH iv_content INTO sy-msgli.
      zcx_eui_no_check=>raise_sys_error( ).
    ENDIF.

    DATA lv_char TYPE c.
    lv_char = iv_content+lv_pos(1).
    CASE lv_char.
      WHEN '}'.
        lv_br_count = lv_br_count - 1.
      WHEN '{'.
        lv_br_count = lv_br_count + 1.
    ENDCASE.
  ENDWHILE.

  " New name
  DATA lv_new_len TYPE i.
  lv_new_len = lv_pos - l_beg.
  cs_scope-field = iv_content+l_beg(lv_new_len).

  " New whole field
  cs_scope-end = cs_scope-end - strlen( cv_whole_field ) + lv_new_len.
  cv_whole_field = cs_scope-field.
ENDMETHOD.


METHOD _inline_tree.
  DATA ls_extra_tab_opt LIKE LINE OF mt_extra_tab_opt.
  DATA lv_rem           TYPE string.

  ls_extra_tab_opt-group = abap_undefined.
  SPLIT is_scope-field AT ';' INTO ls_extra_tab_opt-name lv_rem.

  " Set additional options
  FIELD-SYMBOLS <ls_pair> LIKE LINE OF is_scope-t_pair.
  LOOP AT is_scope-t_pair TRANSPORTING NO FIELDS WHERE key = 'direction'
                                                    OR key = 'group'. "#EC CI_SORTSEQ
    EXIT.
  ENDLOOP.
  CHECK sy-subrc = 0.

  " Only 2 kind of keys
  LOOP AT is_scope-t_pair ASSIGNING <ls_pair>.
    CASE <ls_pair>-key.
      WHEN 'direction'.
        ls_extra_tab_opt-direction = <ls_pair>-val.
      WHEN 'group'.
        ls_extra_tab_opt-group     = <ls_pair>-val.
      WHEN OTHERS.
        MESSAGE w017(zsy_xtt) WITH <ls_pair>-key INTO sy-msgli.
        io_xtt->add_log_message( iv_syst = abap_true ).
    ENDCASE.
  ENDLOOP.

  " Find a match by name
  " TRANSLATE ls_extra_tab_opt-name TO UPPER CASE. Better make case sensetive

  INSERT ls_extra_tab_opt INTO TABLE mt_extra_tab_opt.
  IF sy-subrc <> 0.
    MESSAGE e016(zsy_xtt) WITH ls_extra_tab_opt-name INTO sy-msgli.
    zcx_eui_no_check=>raise_sys_error( ).
  ENDIF.

  " Yes create new tree
  rv_ok = abap_true.

**********************************************************************
  " Find matching & create a new tree
  CHECK ls_extra_tab_opt-group <> abap_undefined. " group could be empty

  " Silent ?
  FIELD-SYMBOLS <ls_field> LIKE LINE OF mo_block->mt_fields.
  READ TABLE mo_block->mt_fields ASSIGNING <ls_field>
   WITH TABLE KEY name = ls_extra_tab_opt-name.
  IF sy-subrc <> 0.
    RETURN.
  ENDIF.

  " No such table
  IF <ls_field>-typ <> mo_block->mc_type-table.
    MESSAGE e018(zsy_xtt) WITH <ls_field>-name INTO sy-msgli.
    zcx_eui_no_check=>raise_sys_error( ).
  ENDIF.

  DATA lv_group1 TYPE string.
  DATA lv_group2 TYPE string.
  SPLIT ls_extra_tab_opt-group AT '-' INTO lv_group1 lv_group2.

  " Have both parts
  IF lv_group2 IS NOT INITIAL.
    <ls_field>-dref = mo_block->tree_create_relat(
      it_table      = <ls_field>-dref
      iv_node_key   = lv_group1
      iv_relat_key  = lv_group2 ).
    RETURN.
  ENDIF.

  " Only now is tree
  <ls_field>-typ = mo_block->mc_type-tree.

  " Fields separeted by ;
  <ls_field>-dref = mo_block->tree_create(
   it_table      = <ls_field>-dref
   iv_fields     = lv_group1 ).
ENDMETHOD.


METHOD _is_level_norm.
  IF mo_block->ms_ext-rb_level + 1 < ir_scope->sc_level.
    CLEAR ir_scope->end.
    RETURN.
  ENDIF.

  rv_ok = abap_true.
ENDMETHOD.
ENDCLASS.