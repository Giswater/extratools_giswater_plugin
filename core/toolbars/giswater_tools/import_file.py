"""
This file is part of Giswater 3
The program is free software: you can redistribute it and/or modify it under the terms of the GNU
General Public License as published by the Free Software Foundation, either version 3 of the License,
or (at your option) any later version.
"""
# -*- coding: utf-8 -*-
import os
import sqlite3
from functools import partial

from qgis.PyQt.QtCore import QDate, QDateTime
from qgis.PyQt.QtWidgets import QGridLayout, QToolButton, QWidget
from qgis.core import QgsApplication, QgsDataSourceUri, QgsProject, QgsVectorLayer, QgsVectorLayerExporter

from ...threads.dfx_execute import GwDxfExtraTool
from ...threads.gpkg_execute import GwGpkgExtraTool
from ...ui.ui_manager import ImportFileUi
from .... import global_vars
from ....settings import tools_qgis, tools_qt, tools_gw, tools_db, dlg, tools_os, tools_log


class ImportFile(dlg.GwAction):

    def __init__(self, icon_path, action_name, text, toolbar, action_group):
        super().__init__(icon_path, action_name, text, toolbar, action_group)
        self.state_types = None
        self.temp_layers_added = []


    def clicked_event(self):

        self.dlg_import_file = ImportFileUi()
        tools_gw.load_settings(self.dlg_import_file)
        self.dlg_import_file.progressBar.setVisible(False)
        self.dlg_import_file.btn_cancel.setEnabled(False)

        self.cld_builtdate = tools_qt.create_datetime('cld_builtdate')

        lyt_config = self.dlg_import_file.findChild(QGridLayout, 'lyt_option_parameters')
        if lyt_config in (None, 'null', 'NULL', 'Null'):
            return
        lyt_config.addWidget(self.cld_builtdate, 3, 1)
        self._fill_widgets()

        # Signals
        self.dlg_import_file.btn_run.clicked.connect(partial(self._execute_function, self.dlg_import_file))
        self.dlg_import_file.chk_dxf_active_layer.stateChanged.connect(partial(self._manage_path_editability, self.dlg_import_file.chk_dxf_active_layer, self.dlg_import_file.txt_dxf_path))
        self.dlg_import_file.btn_dxf_check.clicked.connect(partial(self._import_dxf, self.dlg_import_file, self.temp_layers_added))
        self.dlg_import_file.btn_path.clicked.connect(partial(self._set_dxf_path, self.dlg_import_file.txt_dxf_path))
        self.dlg_import_file.cmb_state.currentIndexChanged.connect(partial(self._update_state_types))
        self.dlg_import_file.btn_close.clicked.connect(partial(tools_gw.close_dialog, self.dlg_import_file))
        self.dlg_import_file.btn_cancel.clicked.connect(partial(self._remove_layers))
        self.dlg_import_file.btn_cancel.clicked.connect(partial(tools_gw.close_dialog, self.dlg_import_file))
        self.dlg_import_file.rejected.connect(self._save_user_values)
        self.dlg_import_file.btn_run.setEnabled(False)
        self.dlg_import_file.btn_cancel.setEnabled(False)

        # Tab GPKG
        self.dlg_import_file.btn_gpkg_check.clicked.connect(partial(self._import_gpkg, self.dlg_import_file, self.temp_layers_added))
        self.dlg_import_file.btn_gpkg_path.clicked.connect(partial(self._set_gpkg_path, self.dlg_import_file.txt_gpkg_path))
        self.dlg_import_file.chk_gpkg_active_layer.stateChanged.connect(partial(self._manage_path_editability, self.dlg_import_file.chk_gpkg_active_layer, self.dlg_import_file.txt_gpkg_path))

        self._load_user_values()

        # TODO:: Remove this wip remove tab after demo
        self.dlg_import_file.mainTab.removeTab(0)

        tools_gw.open_dialog(self.dlg_import_file, dlg_name='toolbox')


    def _execute_function(self, dialog):
        """
        Set background task 'GwDxfExtraTool'
        or
        Set background task 'GwGpkgExtraTool'
        """

        dialog.btn_cancel.setEnabled(True)

        description = f"ToolBox function"

        if self.function_process == 'dxf':
            self.task = GwDxfExtraTool(description, dialog)
        elif self.function_process == 'gpkg':
            self.task = GwGpkgExtraTool(description, dialog)
        else: return
        QgsApplication.taskManager().addTask(self.task)
        QgsApplication.taskManager().triggerTask(self.task)

        dialog.btn_cancel.clicked.connect(self._cancel_task)


    def _cancel_task(self):
        if hasattr(self, 'dxf_task'):
            self.task.cancel()


    def _import_dxf(self, dialog, temp_layers_added):
        """ Function called in def add_button(self, dialog, field): -->
                widget.clicked.connect(partial(getattr(module, function_name), **kwargs)) """

        self.function_process = 'dxf'

        if tools_qt.is_checked(self.dlg_import_file, self.dlg_import_file.chk_dxf_active_layer):
            path = False
        else:
            path = tools_qt.get_text(self.dlg_import_file, self.dlg_import_file.txt_dxf_path)

        complet_result = self._manage_dxf(dialog, path, False, True)

        if complet_result:
            for layer in complet_result['temp_layers_added']:
                temp_layers_added.append(layer)

            tools_gw.manage_json_return(complet_result['result'], 'gw_fct_check_importdxf')

            dialog.btn_run.setEnabled(True)

            # Fill tab log
            # TODO:: set tab_idx=2 when recover tab dxf
            tools_gw.fill_tab_log(self.dlg_import_file, complet_result['result']['body']['data'], tab_idx=1,
                                  call_set_tabs_enabled=False)


    def _import_gpkg(self, dialog, temp_layers_added):
        """ Function called in def add_button(self, dialog, field): -->
                widget.clicked.connect(partial(getattr(module, function_name), **kwargs)) """

        self.function_process = 'gpkg'

        if tools_qt.is_checked(self.dlg_import_file, self.dlg_import_file.chk_gpkg_active_layer):
            path = False
        else:
            path = tools_qt.get_text(self.dlg_import_file, self.dlg_import_file.txt_gpkg_path)
        complet_result = self._manage_gpkg(dialog, path, False, True)

        if complet_result:
            for layer in complet_result['temp_layers_added']:
                temp_layers_added.append(layer)

            tools_gw.manage_json_return(complet_result['result'], 'gw_fct_check_importgpkg')

            dialog.btn_run.setEnabled(True)

            # Fill tab log
            # TODO:: set tab_idx=2 when  recover tab dxf
            tools_gw.fill_tab_log(self.dlg_import_file, complet_result['result']['body']['data'], tab_idx=1,
                                  call_set_tabs_enabled=False)


    def _set_gpkg_path(self, widget):
        """ Function called in def add_button(self, dialog, field): -->
                widget.clicked.connect(partial(getattr(module, function_name), **kwargs)) """

        path, filter_ = tools_os.open_file_path("Select GPKG file", "GPKG Files (*.gpkg)")

        if not path:
            return

        widget.setText(path)


    def _set_dxf_path(self, widget):
        """ Function called in def add_button(self, dialog, field): -->
                widget.clicked.connect(partial(getattr(module, function_name), **kwargs)) """

        path, filter_ = tools_os.open_file_path("Select DXF file", "GPKG Files (*.dxf)")

        if not path:
            return

        widget.setText(path)


    def _remove_layers(self):
        """ Remove the layers put on the toc by the tool """

        root = QgsProject.instance().layerTreeRoot()
        for layer in reversed(self.temp_layers_added):
            self.temp_layers_added.remove(layer)
            # Possible QGIS bug: Instead of returning None because it is not found in the TOC, it breaks
            try:
                dem_raster = root.findLayer(layer.id())
            except RuntimeError:
                continue

            parent_group = dem_raster.parent()
            try:
                QgsProject.instance().removeMapLayer(layer.id())
            except Exception:
                pass

            if len(parent_group.findLayers()) == 0:
                root.removeChildNode(parent_group)


    def _load_user_values(self):

        # Tab dxf
        state = tools_gw.get_config_parser('import_file', 'state', 'user', 'session')
        tools_qt.set_combo_value(self.dlg_import_file.cmb_state, state, 0)
        state_type = tools_gw.get_config_parser('import_file', 'state_type', 'user', 'session')
        tools_qt.set_combo_value(self.dlg_import_file.cmb_state_type, state_type, 0)
        workcat = tools_gw.get_config_parser('import_file', 'workcat', 'user', 'session')
        tools_qt.set_combo_value(self.dlg_import_file.cmb_workcat, workcat, 0)
        arc_type = tools_gw.get_config_parser('import_file', 'arc_type', 'user', 'session')
        tools_qt.set_combo_value(self.dlg_import_file.cmb_arc_type, arc_type, 0)
        node_type = tools_gw.get_config_parser('import_file', 'node_type', 'user', 'session')
        tools_qt.set_combo_value(self.dlg_import_file.cmb_node_type, node_type, 0)
        topocontrol = tools_gw.get_config_parser('import_file', 'topocontrol', 'user', 'session')
        tools_qt.set_checked(self.dlg_import_file, self.dlg_import_file.chk_topocontrol,
                             tools_os.set_boolean(topocontrol))
        builtdate = tools_gw.get_config_parser('import_file', 'builtdate', 'user', 'session')
        if builtdate not in ('', None, 'null'):
            date = QDate.fromString(builtdate.replace('/', '-'), 'yyyy-MM-dd')
            tools_qt.set_calendar(self.dlg_import_file, 'cld_builtdate', date)
        else:
            self.cld_builtdate.clear()

        # Tab gpkg
        feature_type = tools_gw.get_config_parser('import_file', 'feature_type', 'user', 'session')
        tools_qt.set_combo_value(self.dlg_import_file.cmb_feature_type, feature_type, 0)
        gpkg_topocontrol = tools_gw.get_config_parser('import_file', 'gpkg_topocontrol', 'user', 'session')
        tools_qt.set_checked(self.dlg_import_file, self.dlg_import_file.chk_gpkg_topocontrol,
                             tools_os.set_boolean(gpkg_topocontrol))


    def _save_user_values(self):

        # Tab dxf
        state = tools_qt.get_combo_value(self.dlg_import_file, self.dlg_import_file.cmb_state, 0)
        tools_gw.set_config_parser('import_file', 'state', f"{state}")
        state_type = tools_qt.get_combo_value(self.dlg_import_file, self.dlg_import_file.cmb_state_type, 0)
        tools_gw.set_config_parser('import_file', 'state_type', f"{state_type}")
        workcat = tools_qt.get_combo_value(self.dlg_import_file, self.dlg_import_file.cmb_workcat, 0)
        tools_gw.set_config_parser('import_file', 'workcat', f"{workcat}")
        arc_type = tools_qt.get_combo_value(self.dlg_import_file, self.dlg_import_file.cmb_arc_type, 0)
        tools_gw.set_config_parser('import_file', 'arc_type', f"{arc_type}")
        node_type = tools_qt.get_combo_value(self.dlg_import_file, self.dlg_import_file.cmb_node_type, 0)
        tools_gw.set_config_parser('import_file', 'node_type', f"{node_type}")
        topocontrol = tools_qt.is_checked(self.dlg_import_file, self.dlg_import_file.chk_topocontrol)
        tools_gw.set_config_parser('import_file', 'topocontrol', f"{topocontrol}")
        builtdate = tools_qt.get_calendar_date(self.dlg_import_file, 'cld_builtdate')
        tools_gw.set_config_parser('import_file', 'builtdate', f"{builtdate}")

        # Tab gpkg
        feature_type = tools_qt.get_combo_value(self.dlg_import_file, self.dlg_import_file.cmb_feature_type, 0)
        tools_gw.set_config_parser('import_file', 'feature_type', f"{feature_type}")
        gpkg_topocontrol = tools_qt.is_checked(self.dlg_import_file, self.dlg_import_file.chk_gpkg_topocontrol)
        tools_gw.set_config_parser('import_file', 'gpkg_topocontrol', f"{gpkg_topocontrol}")


    def _update_state_types(self):
        """ Updates the child combo values when the parent combo moves """

        state = tools_qt.get_combo_value(self.dlg_import_file, self.dlg_import_file.cmb_state, 0)
        new_state_types = []
        for state_type in self.state_types:
            if state_type[2] == state:
                new_state_types.append(state_type)
        tools_qt.fill_combo_values(self.dlg_import_file.cmb_state_type, new_state_types, 1)


    def _fill_widgets(self):
        """ Fill the widgets with the values of the dv """

        sql = "SELECT descript FROM sys_function WHERE id = 2784;"
        row = tools_db.get_row(sql)
        if row:
            tools_qt.set_widget_text(self.dlg_import_file, self.dlg_import_file.txt_info, row[0])

        sql = "SELECT id, name FROM value_state"
        self.states = tools_db.get_rows(sql)
        tools_qt.fill_combo_values(self.dlg_import_file.cmb_state, self.states, 1)

        sql = "SELECT id, name, state FROM value_state_type;"
        self.state_types = tools_db.get_rows(sql)
        tools_qt.fill_combo_values(self.dlg_import_file.cmb_state_type, self.state_types, 1)

        sql = "SELECT id, id FROM cat_work;"
        rows = tools_db.get_rows(sql)
        tools_qt.fill_combo_values(self.dlg_import_file.cmb_workcat, rows, 1)

        sql = "SELECT id, id FROM cat_feature_arc;"
        rows = tools_db.get_rows(sql)
        tools_qt.fill_combo_values(self.dlg_import_file.cmb_arc_type, rows, 1)

        sql = "SELECT id, id FROM cat_feature_node;"
        rows = tools_db.get_rows(sql)
        tools_qt.fill_combo_values(self.dlg_import_file.cmb_node_type, rows, 1)

        feature_types = [["arc", "Arc"], ["node", "Node"], ["connec", "Connec"], ["link", "Link"]]
        tools_qt.fill_combo_values(self.dlg_import_file.cmb_feature_type, feature_types, 1)


    def _populate_cmb_type(self, feature_types):

        feat_types = []
        for item in feature_types:
            elem = [item.upper(), item.upper()]
            feat_types.append(elem)
        if feat_types and len(feat_types) <= 1:
            self.dlg_functions.cmb_feature_type.setVisible(False)
        tools_qt.fill_combo_values(self.dlg_functions.cmb_feature_type, feat_types, 1)


    def _manage_dxf(self, dialog, dxf_path, export_to_db=False, toc=False, del_old_layers=True):
        """ Select a dxf file and add layers into toc
        :param dialog: (QDialog)
        :param dxf_path: path of dxf file
        :param export_to_db: Export layers to database
        :param toc: insert layers into TOC
        :param del_old_layers: look for a layer with the same name as the one to be inserted and delete it
        :return:
        """

        srid = tools_qgis.get_plugin_settings_value('srid')
        # Block the signals so that the window does not appear asking for crs / srid and / or alert message
        global_vars.iface.mainWindow().blockSignals(True)
        dialog.txt_infolog.clear()

        sql = "DELETE FROM temp_table WHERE fid = 206;\n"
        tools_db.execute_sql(sql)
        temp_layers_added = []
        for type_ in ['LineString', 'Point', 'Polygon']:

            if dxf_path is not False:
                # Get file name without extension
                dxf_output_filename = os.path.splitext(os.path.basename(dxf_path))[0]

                # Create layer
                uri = f"{dxf_path}|layername=entities|geometrytype={type_}"
                dxf_layer = QgsVectorLayer(uri, f"{dxf_output_filename}_{type_}", 'ogr')
                # Set crs to layer
                crs = dxf_layer.sourceCrs()
                crs.createFromString(srid)
                dxf_layer.setCrs(crs)

                if not dxf_layer.hasFeatures():
                    continue

                if del_old_layers:
                    tools_qgis.remove_layer_from_toc(dxf_layer.name(), 'GW Temporal Layers')

                if toc:
                    if dxf_layer.isValid():
                        self._add_layer_toc_from_file(dxf_layer, 'GW Temporal Layers')
                        temp_layers_added.append(dxf_layer)
            else:
                dxf_layer = self.iface.activeLayer()

            # Get the name of the columns
            field_names = [field.name() for field in dxf_layer.fields()]

            sql = ""
            geom_types = {0: 'geom_point', 1: 'geom_line', 2: 'geom_polygon'}
            for count, feature in enumerate(dxf_layer.getFeatures()):
                geom_type = feature.geometry().type()
                sql += (f"INSERT INTO temp_table (fid, text_column, {geom_types[int(geom_type)]})"
                        f" VALUES (206, '{{")
                for att in field_names:
                    if feature[att] in (None, 'NULL', ''):
                        sql += f'"{att}":null , '
                    else:
                        sql += f'"{att}":"{feature[att]}" , '
                geometry = self._manage_geometry(feature.geometry())
                sql = sql[:-2] + f"}}', (SELECT ST_GeomFromText('{geometry}', {srid})));\n"
                if count != 0 and count % 500 == 0:
                    status = tools_db.execute_sql(sql)
                    if not status:
                        return False
                    sql = ""

            if sql != "":
                status = tools_db.execute_sql(sql)
                if not status:
                    return False

            if export_to_db:
                self._export_layer_to_db(dxf_layer, crs)


        # Unlock signals
        global_vars.iface.mainWindow().blockSignals(False)

        result = tools_gw.execute_procedure('gw_fct_check_importdxf', None)

        if not result or result['status'] == 'Failed':
            return False

        return {"path": dxf_path, "result": result, "temp_layers_added": temp_layers_added}


    def _manage_gpkg(self, dialog, gpkg_path, export_to_db=False, toc=False, del_old_layers=True):
        """ Select a gpkg file and add layers into toc
        :param dialog: (QDialog)
        :param gpkg_path: path of gpkg file
        :param export_to_db: Export layers to database
        :param toc: insert layers into TOC
        :param del_old_layers: look for a layer with the same name as the one to be inserted and delete it
        :return:
        """

        srid = tools_qgis.get_plugin_settings_value('srid')
        feature_type = tools_qt.get_combo_value(self.dlg_import_file, self.dlg_import_file.cmb_feature_type, 0)
        # Block the signals so that the window does not appear asking for crs / srid and / or alert message
        global_vars.iface.mainWindow().blockSignals(True)
        dialog.txt_infolog.clear()

        sql = f"DELETE FROM temp_import_{feature_type} WHERE fid = 392;\n"
        tools_db.execute_sql(sql)
        temp_layers_added = []
        if gpkg_path is not False:
            sqlite_conn, cursor = self.create_sqlite_conn(gpkg_path)
            if sqlite_conn:
                sql = (f"SELECT identifier FROM gpkg_contents")
                cursor.execute(sql)
                row = cursor.fetchone()
            else:
                return

            # append the layername part
            gpkg_countries_layer = gpkg_path + f"|layername={row[0]}"

            # e.g. gpkg_places_layer = "/usr/share/qgis/resources/data/world_map.gpkg|layername=countries"
            vlayer = QgsVectorLayer(gpkg_countries_layer, f"{row[0]}_gpkg", "ogr")
            if vlayer.isValid():
                # QgsProject.instance().addMapLayer(vlayer)
                tools_qgis.remove_layer_from_toc(vlayer.name(), 'GW Temporal Layers')
                self._add_layer_toc_from_file(vlayer, 'GW Temporal Layers')
                temp_layers_added.append(vlayer)
        else:
            vlayer = self.iface.activeLayer()

        sql = ""
        field_names = [field.name() for field in vlayer.fields()]
        for count, feature in enumerate(vlayer.getFeatures()):

            sql += f"INSERT INTO temp_import_{feature_type} (fid, cur_user, the_geom "

            for att in field_names:
                sql += f', "{att}" '

            sql += f") VALUES (392, current_user "
            geometry = self._manage_geometry(feature.geometry())
            sql += f", (SELECT ST_GeomFromText('{geometry}', {srid}))"
            for att in field_names:
                if feature[att] in (None, 'NULL', ''):
                    sql += f", null "
                else:
                    if type(feature[att]) is QDateTime:
                        sql += f", '{feature[att].toString('yyyy-MM-dd HH:mm:ss')}' "
                    else:
                        sql += f", '{feature[att]}' "
            sql += f");\n"

            if count != 0 and count % 500 == 0:
                status = tools_db.execute_sql(sql)
                if not status:
                    return False
                sql = ""

        if sql != "":
            status = tools_db.execute_sql(sql)
            if not status:
                return False


        # Unlock signals
        global_vars.iface.mainWindow().blockSignals(False)
        feature = '"featureType":"' + str(feature_type.upper()) + '"'
        body = tools_gw.create_body(feature=feature)
        result = tools_gw.execute_procedure('gw_fct_check_importgpkg', body)

        if not result or result['status'] == 'Failed':
            return False

        return {"path": gpkg_path, "result": result, "temp_layers_added": temp_layers_added}


    def create_sqlite_conn(self, db_path):
        """ Creates an sqlite connection to a file """

        status = False
        cursor = None
        try:
            # db_path = f"{global_vars.plugin_dir}{os.sep}resources{os.sep}gis{os.sep}{file_name}.sqlite"
            tools_log.log_info(db_path)
            if os.path.exists(db_path):
                conn = sqlite3.connect(db_path)
                cursor = conn.cursor()
                status = True
            else:
                tools_log.log_warning("Config database file not found", parameter=db_path)
        except Exception as e:
            tools_log.log_warning(str(e))

        return status, cursor


    def _manage_geometry(self, geometry):
        """ Get QgsGeometry and return as text
         :param geometry: (QgsGeometry)
         :return: (String)
        """
        geometry = geometry.asWkt().replace('Z (', ' (')
        geometry = geometry.replace(' 0)', ')')
        return geometry


    def _export_layer_to_db(self, layer, crs):
        """ Export layer to postgres database
        :param layer: (QgsVectorLayer)
        :param crs: QgsVectorLayer.crs() (crs)
        """

        sql = f'DROP TABLE "{layer.name()}";'
        tools_db.execute_sql(sql)

        schema_name = global_vars.session_vars['credentials']['schema'].replace('"', '')
        uri = self._set_uri()
        uri.setDataSource(schema_name, layer.name(), None, "", layer.name())

        error = QgsVectorLayerExporter.exportLayer(
            layer, uri.uri(), global_vars.session_vars['credentials']['user'], crs, False)
        if error[0] != 0:
            tools_log.log_info(F"ERROR --> {error[1]}")


    def _add_layer_toc_from_file(self, layer, dxf_output_filename):
        """  Read a dxf file and put result into TOC
        :param layer: (QgsVectorLayer)
        :param dxf_output_filename: Name of layer into TOC (string)
        :return: layer (QgsVectorLayer)
        """

        QgsProject.instance().addMapLayer(layer, False)
        root = QgsProject.instance().layerTreeRoot()
        my_group = root.findGroup(dxf_output_filename)
        if my_group is None:
            my_group = root.insertGroup(0, dxf_output_filename)
        my_group.insertLayer(0, layer)
        global_vars.canvas.refreshAllLayers()
        return layer

    # TODO:: UNIQUE Function with _add_layer_toc_from_file (parametrize variables)
    def _add_layer_toc_from_gpkg(self, gpkg_layer, gpkg_output_filename):
        """  Read a gpkg file and put result into TOC
        :param gpkg_layer: (QgsVectorLayer)
        :param gpkg_output_filename: Name of layer into TOC (string)
        :return: gpkg_layer (QgsVectorLayer)
        """

        QgsProject.instance().addMapLayer(gpkg_layer, False)
        root = QgsProject.instance().layerTreeRoot()
        my_group = root.findGroup(gpkg_output_filename)
        if my_group is None:
            my_group = root.insertGroup(0, gpkg_output_filename)
        my_group.insertLayer(0, gpkg_layer)
        global_vars.canvas.refreshAllLayers()
        return gpkg_layer


    def _set_uri(self):
        """ Set the component parts of a RDBMS data source URI
        :return: QgsDataSourceUri() with the connection established according to the parameters of the credentials.
        """

        uri = QgsDataSourceUri()
        uri.setConnection(global_vars.session_vars['credentials']['host'],
                          global_vars.session_vars['credentials']['port'],
                          global_vars.session_vars['credentials']['db'],
                          global_vars.session_vars['credentials']['user'],
                          global_vars.session_vars['credentials']['password'])
        return uri


    def _manage_path_editability(self, chk, widget):

        import_active_layer = tools_qt.is_checked(self.dlg_import_file, chk)

        if import_active_layer:
            widget.setEnabled(False)
        else:
            widget.setEnabled(True)
            
        widget.clear()
