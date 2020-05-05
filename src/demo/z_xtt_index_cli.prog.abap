*&---------------------------------------------------------------------*
*&---------------------------------------------------------------------*

CLASS cl_main IMPLEMENTATION.
  METHOD constructor.
    DATA:
      lt_wwwdata    TYPE STANDARD TABLE OF wwwdata WITH DEFAULT KEY,
      lv_grp        TYPE num2,
      lv_prev_grp   TYPE num2,
      lv_number     TYPE num2,
      ls_screen_opt LIKE LINE OF mt_screen_opt,
      lt_list       TYPE vrm_values,
      ls_list       TYPE REF TO vrm_value,
      lv_desc       TYPE string.
    FIELD-SYMBOLS:
      <ls_wwwdata>  LIKE LINE OF lt_wwwdata.

    DEFINE add_to_list.
      APPEND INITIAL LINE TO lt_list REFERENCE INTO ls_list.
      CONCATENATE lv_grp '-' lv_number INTO ls_list->key.
      lv_number = lv_number + 1.

      ls_list->text = &1.
      IF lv_desc IS NOT INITIAL.
       CONCATENATE ls_list->text ` - ` lv_desc INTO ls_list->text.
      ENDIF.
    END-OF-DEFINITION.

    " Parameter settings for Web Reporting
    SELECT DISTINCT objid text  "##TOO_MANY_ITAB_FIELDS
       INTO CORRESPONDING FIELDS OF TABLE lt_wwwdata
    FROM wwwdata
    WHERE objid LIKE 'ZXXT_%'
    ORDER BY objid.                                     "#EC CI_NOFIRST

    " Fill examples
    LOOP AT lt_wwwdata ASSIGNING <ls_wwwdata>.
      CLEAR:
       lv_desc,
       ls_screen_opt.
      lv_grp = <ls_wwwdata>-objid+5(2).
      ls_screen_opt-template = <ls_wwwdata>-objid.

      " New example group
      IF lv_grp <> lv_prev_grp.
        lv_prev_grp = lv_grp.
        CLEAR lv_number.
        add_to_list '---------------------------------------'.
      ENDIF.

      IF <ls_wwwdata>-objid CP '*_DOC*'.
        ls_screen_opt-class_name = 'ZCL_XTT_WORD_DOCX'.
        lv_desc                  = 'Word'.                  "#EC NOTEXT

      ELSEIF <ls_wwwdata>-objid CP '*_XLS*'.
        ls_screen_opt-class_name = 'ZCL_XTT_EXCEL_XLSX'.
        lv_desc                  = 'Excel'.                 "#EC NOTEXT

      ELSEIF <ls_wwwdata>-objid CP '*WORD*_XML'.
        ls_screen_opt-class_name = 'ZCL_XTT_WORD_XML'.
        lv_desc                  = 'Word XML'.              "#EC NOTEXT
        ls_screen_opt-show_zip = abap_true.

      ELSEIF <ls_wwwdata>-objid CP '*EXCEL*_XML'.
        ls_screen_opt-class_name = 'ZCL_XTT_EXCEL_XML'.
        lv_desc                  = 'Excel XML'.             "#EC NOTEXT
        ls_screen_opt-show_zip = abap_true.

      ELSEIF <ls_wwwdata>-objid CP '*_PDF' OR <ls_wwwdata>-objid CP '*_XDP'.
        ls_screen_opt-class_name = 'ZCL_XTT_PDF'.
        lv_desc                  = 'Adobe PDF'.             "#EC NOTEXT

      ELSEIF <ls_wwwdata>-objid CP '*_HTM*'.
        ls_screen_opt-class_name = 'ZCL_XTT_HTML'.
        lv_desc                  = 'Html'.                  "#EC NOTEXT
      ENDIF.

      " Additional parameters
      CASE lv_grp.
        WHEN 02.
          ls_screen_opt-show_row_count = abap_true.

        WHEN 03.
          ls_screen_opt-show_row_count   = abap_true.
          ls_screen_opt-show_block_count = abap_true.

        WHEN 05.
          ls_screen_opt-show_row_count   = abap_true.

        WHEN 08.
          ls_screen_opt-show_row_count   = abap_true.

        WHEN 09.
          ls_screen_opt-show_row_count   = abap_true.
          ls_screen_opt-show_colum_count = abap_true.
      ENDCASE.

      " Add with description
      add_to_list <ls_wwwdata>-text.

      " And add
      ls_screen_opt-key = ls_list->key.
      INSERT ls_screen_opt INTO TABLE mt_screen_opt.
    ENDLOOP.

    " Update listbox
    CALL FUNCTION 'VRM_SET_VALUES'
      EXPORTING
        id     = 'P_EXA'
        values = lt_list.

    " Send to current user
    SELECT SINGLE adr6~smtp_addr INTO p_email
    FROM adr6
    INNER JOIN usr21 ON usr21~addrnumber = adr6~addrnumber AND usr21~persnumber = adr6~persnumber
    WHERE usr21~bname = sy-uname.                       "#EC CI_NOORDER

    " First item
    p_exa = '01-00'.

    " 1010
    cl_gui_frontend_services=>get_desktop_directory(
     CHANGING
       desktop_directory = p_r_path ).
  ENDMETHOD.

  METHOD check_break_point_id.
    DATA:
      lv_exp_tstamp   TYPE aab_id_act-exp_tstamp,
      lv_date         TYPE d,
      lv_time         TYPE t,
      lv_datetime_db  TYPE char14,
      lv_datetime_now TYPE char14.

    " Activatable IDs for Breakpoints and Assertions: Activation
    SELECT SINGLE exp_tstamp INTO lv_exp_tstamp
    FROM aab_id_act
    WHERE name       = 'ZXTT_BREAK_POINT'
      AND username   = sy-uname
      AND server     = space
      AND is_program = space
      AND actdefault = space.

    " Convert to SAP
    CONVERT TIME STAMP lv_exp_tstamp TIME ZONE sy-zonlo
      INTO DATE lv_date TIME lv_time.

    " For comaparison
    CONCATENATE lv_date  lv_time  INTO lv_datetime_db.
    CONCATENATE sy-datum sy-uzeit INTO lv_datetime_now.

    CHECK lv_datetime_now > lv_datetime_db.
    MESSAGE 'Activate ZXTT_BREAK_POINT in tr. SAAB'(tbr) TYPE 'S' DISPLAY LIKE 'E'.
  ENDMETHOD.

  METHOD pbo.
    DATA:
      ls_screen_opt TYPE ts_screen_opt,
      l_show        TYPE abap_bool.

    " Show or hide controls
    READ TABLE mt_screen_opt INTO ls_screen_opt
     WITH TABLE KEY key = p_exa.

    LOOP AT SCREEN.
      IF ls_screen_opt IS INITIAL.
        CHECK screen-group1 <> 'EXA' AND screen-group1 IS NOT INITIAL.
        l_show = abap_false.
      ELSE.
        l_show = abap_true.

        CASE screen-group1.
          WHEN 'DWN'. " Additional parameters for `download` method
            IF p_stru = abap_true OR p_dwnl <> abap_true.
              l_show = abap_false.
            ENDIF.

          WHEN 'SND'. " Additional parameters for `send` method
            IF p_stru = abap_true OR p_send <> abap_true.
              l_show = abap_false.
            ENDIF.

          WHEN 'RES'. " Last index is the documentation
*          IF p_exa = .
*            l_show = p_temp = p_stru = abap_false.
*          ENDIF.

          WHEN 'MET'. " Dont'show data, just data structure
            IF p_stru = abap_true.
              l_show = abap_false.
            ELSEIF screen-name CP '*P_SHOW*'.
              l_show = abap_true.
            ENDIF.

          WHEN OTHERS.
            IF screen-name CP '*P_R_CNT*'.
              l_show = ls_screen_opt-show_row_count.
            ELSEIF screen-name CP '*P_C_CNT*'.
              l_show = ls_screen_opt-show_colum_count.
            ELSEIF screen-name CP '*P_B_CNT*'.
              l_show = ls_screen_opt-show_block_count.
            ELSEIF screen-name CP '*P_ZIP*'.
              l_show = ls_screen_opt-show_zip.
            ELSE.
              CONTINUE.
            ENDIF.
        ENDCASE.
      ENDIF.

      " Show or hide paramater
      IF l_show = abap_true.
        screen-invisible = '0'.
        screen-input     = '1'.
      ELSE.
        screen-invisible = '1'.
        screen-input     = '0'.
      ENDIF.
      MODIFY SCREEN.
    ENDLOOP.
  ENDMETHOD.

  METHOD pai.

  ENDMETHOD.

  METHOD start_of_selection.
    DATA:
      ls_screen_opt TYPE REF TO ts_screen_opt,
      lv_meth       TYPE string,
      lo_recipient  TYPE REF TO if_recipient_bcs,
      lt_recipient  TYPE rmps_recipient_bcs,
      lo_err        TYPE REF TO cx_address_bcs,
      lv_text       TYPE string,
      lo_xtt        TYPE REF TO zcl_xtt.

    " Current example
    READ TABLE mt_screen_opt REFERENCE INTO ls_screen_opt
     WITH TABLE KEY key = p_exa.

    IF sy-subrc <> 0.
      MESSAGE 'Please select example'(pse) TYPE 'S' DISPLAY LIKE 'E'.
      RETURN.
    ENDIF.

    " Get parameters for merge method
    CONCATENATE 'EXAMPLE_' ls_screen_opt->key(2) INTO lv_meth.
    CALL METHOD me->(lv_meth)
      EXPORTING
        iv_class_name = ls_screen_opt->class_name
        iv_template   = ls_screen_opt->template
      RECEIVING
        ro_xtt        = lo_xtt.

    " Call respective method
    CHECK lo_xtt IS NOT INITIAL.

    CASE 'X'.
      WHEN p_dwnl.
        IF p_open = abap_true.
          lo_xtt->download(        " All parameters are optional
           EXPORTING
            iv_zip      = p_zip
           CHANGING
            cv_fullpath = p_path ).
        ELSE.
          lo_xtt->download(
           EXPORTING
            iv_open     = p_open " Could be ZCL_XTT=>MC_BY_OLE
            iv_zip      = p_zip
           CHANGING
            cv_fullpath = p_path ).
        ENDIF.

      WHEN p_show.
        lo_xtt->show( ).

      WHEN p_send.
        " Add recipients
        TRY.
            IF p_user IS NOT INITIAL.
              lo_recipient = cl_sapuser_bcs=>create( p_user ).
              APPEND lo_recipient TO lt_recipient.
            ENDIF.

            IF p_email IS NOT INITIAL.
              lo_recipient = cl_cam_address_bcs=>create_internet_address( p_email ).
              APPEND lo_recipient TO lt_recipient.
            ENDIF.
          CATCH cx_address_bcs INTO lo_err.
            lv_text = lo_err->if_message~get_text( ).
            MESSAGE lv_text TYPE 'S' DISPLAY LIKE 'E'.
        ENDTRY.

        CHECK lt_recipient IS NOT INITIAL.
        lo_xtt->send(
         it_recipients = lt_recipient
         iv_subject    = p_title
         iv_body       = p_text ).
    ENDCASE.
  ENDMETHOD.

  METHOD f4_full_path.
    DATA:
      lv_fullpath TYPE string,
      lv_filename TYPE string,
      lv_path     TYPE string,
      lv_result   TYPE i.

    lv_fullpath = cv_fullpath.
    cl_gui_frontend_services=>file_save_dialog(
      EXPORTING
        window_title    = iv_title
      CHANGING
        filename    = lv_filename
        path        = lv_path
        fullpath    = lv_fullpath
        user_action = lv_result
      EXCEPTIONS
        OTHERS      = 1 ).
    CHECK sy-subrc = 0 AND lv_result = cl_gui_frontend_services=>action_ok.
    cv_fullpath = lv_fullpath.
  ENDMETHOD.

  METHOD f4_dir_browse.
    DATA:
      lv_path        TYPE string,
      lv_init_folder TYPE string.

    lv_init_folder = cv_path.
    cl_gui_frontend_services=>directory_browse(
      EXPORTING
        window_title   = iv_title
        initial_folder = lv_init_folder
      CHANGING
        selected_folder = lv_path
      EXCEPTIONS
        OTHERS          = 1 ).

    CHECK sy-subrc = 0 AND lv_path IS NOT INITIAL.
    cv_path = lv_path.
  ENDMETHOD.

  METHOD get_random_table.
    DATA:
      lo_rand_i TYPE REF TO cl_abap_random_int,
      lo_rand_p TYPE REF TO cl_abap_random_packed,
      ls_no_sum TYPE ts_no_sum,
      lv_int    TYPE i,
      lv_column TYPE string.
    FIELD-SYMBOLS:
      <ls_item> TYPE any,
      <lv_sum>  TYPE bf_rbetr. " P with sign

    CLEAR et_table.

    " A,B,C,D chars
    lo_rand_i = cl_abap_random_int=>create( min = 0 max = 3 ).
    " SUMS
    lo_rand_p = cl_abap_random_packed=>create( min = 0 max = 1000000 ).
    DO p_r_cnt TIMES.
      " Fill without sums
      CLEAR ls_no_sum.

      " Special XML symbols <>
      ls_no_sum-caption = sy-index.
      CONCATENATE `<Caption ` ls_no_sum-caption `/>` INTO ls_no_sum-caption.

      " Date
      lv_int = lo_rand_i->get_next( ).
      ls_no_sum-date = sy-datum - lv_int.

      " 3 different groups
      lv_int = lv_int + 65.
      ls_no_sum-group = cl_abap_conv_in_ce=>uccpi( lv_int ).
      CONCATENATE `GRP ` ls_no_sum-group INTO ls_no_sum-group.

      " And finally sums
**********************************************************************
      " in Word and pdf (except Excel formats), 'P' type always has dot as a delimiter
      " If 'N' type has conversion exit it will transformed to mask type
      " Use ;type=mask addition in template for using WRITE ... TO
**********************************************************************

      " Write without sums
      APPEND INITIAL LINE TO et_table ASSIGNING <ls_item>.
      MOVE-CORRESPONDING ls_no_sum TO <ls_item>.

      " Fill R-T-SUM*
      DO iv_column_cnt TIMES.
        " Get column name
        lv_column = sy-index.
        CONDENSE lv_column.
        CONCATENATE `SUM` lv_column INTO lv_column.

        " Exist ?
        ASSIGN COMPONENT lv_column OF STRUCTURE <ls_item> TO <lv_sum>.
        IF sy-subrc <> 0.
          zcx_xtt_exception=>raise_dump( iv_message = `Check data structure` ). "#EC NOTEXT
        ENDIF.

        " Show with decimals
        <lv_sum> = lo_rand_p->get_next( ). " / 100
        <lv_sum> = <lv_sum> / 100.
      ENDDO.
    ENDDO.
  ENDMETHOD.

  INCLUDE z_xtt_index_exa_01.
  INCLUDE z_xtt_index_exa_02.
  INCLUDE z_xtt_index_exa_03.
  INCLUDE z_xtt_index_exa_04.
  INCLUDE z_xtt_index_exa_05.
  INCLUDE z_xtt_index_exa_06.
  INCLUDE z_xtt_index_exa_07.
  INCLUDE z_xtt_index_exa_08.
  INCLUDE z_xtt_index_exa_09.

ENDCLASS.
