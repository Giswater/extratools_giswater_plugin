"""
This file is part of Giswater 3
The program is free software: you can redistribute it and/or modify it under the terms of the GNU
General Public License as published by the Free Software Foundation, either version 3 of the License,
or (at your option) any later version.
"""
# -*- coding: utf-8 -*-
import json
import os
import subprocess
from collections import OrderedDict
from functools import partial

from qgis.core import QgsDataSourceUri, QgsProject, QgsVectorLayer, QgsVectorLayerExporter
from qgis.PyQt.QtWidgets import QMessageBox, QWidget

from ...ui.ui_manager import ImportDxfUi
from .... import global_vars
from ....settings import tools_qgis, tools_qt, tools_gw, tools_db, dialog, toolbox, tools_os, tools_log


class ImportDxf(dialog.GwAction):

    def __init__(self, icon_path, action_name, text, toolbar, action_group):
        super().__init__(icon_path, action_name, text, toolbar, action_group)
        self.toolbox = toolbox.GwToolBoxButton(icon_path, action_name, text, None, action_group)


    def clicked_event(self):

        self.dlg_dxf = ImportDxfUi()
        tools_gw.load_settings(self.dlg_dxf)
        self.dlg_dxf.progressBar.setVisible(False)
        self.dlg_dxf.btn_cancel.setEnabled(False)

        self.dlg_dxf.cmb_layers.currentIndexChanged.connect(
            partial(self.toolbox.set_selected_layer, self.dlg_dxf, self.dlg_dxf.cmb_layers))
        self.dlg_dxf.rbt_previous.toggled.connect(partial(self.toolbox.rbt_state, self.dlg_dxf.rbt_previous))
        self.dlg_dxf.rbt_layer.toggled.connect(partial(self.toolbox.rbt_state, self.dlg_dxf.rbt_layer))
        self.dlg_dxf.rbt_layer.setChecked(True)

        extras = f'"filterText":"Import dxf file"'
        extras += ', "isToolbox":false'
        body = tools_gw.create_body(extras=extras)
        json_result = tools_gw.execute_procedure('gw_fct_gettoolbox', body)
        if not json_result or json_result['status'] == 'Failed':
            return False

        status = self.toolbox.populate_functions_dlg(self.dlg_dxf, json_result['body']['data'], self)
        if not status:
            message = "Function not found"
            tools_qgis.show_message(message, parameter='Import dxf file')
            return

        self.dlg_dxf.btn_run.clicked.connect(
            partial(self.toolbox.execute_function, self.dlg_dxf, self.dlg_dxf.cmb_layers, json_result['body']['data']))
        self.dlg_dxf.btn_close.clicked.connect(partial(tools_gw.close_dialog, self.dlg_dxf))
        self.dlg_dxf.btn_cancel.clicked.connect(partial(self.toolbox.remove_layers))
        self.dlg_dxf.btn_cancel.clicked.connect(partial(tools_gw.close_dialog, self.dlg_dxf))

        self.dlg_dxf.btn_run.setEnabled(False)
        self.dlg_dxf.btn_cancel.setEnabled(False)

        tools_gw.open_dialog(self.dlg_dxf, dlg_name='toolbox')


    def import_dxf(self, **kwargs):
        """ Function called in def add_button(self, dialog, field): -->
                widget.clicked.connect(partial(getattr(module, function_name), **kwargs)) """

        path, filter_ = tools_os.open_file_path("Select DXF file", "DXF Files (*.dxf)")
        if not path:
            return

        dialog = kwargs['dialog']
        widget = kwargs['widget']
        temp_layers_added = kwargs['temp_layers_added']
        complet_result = self._manage_dxf(dialog, path, False, True)

        for layer in complet_result['temp_layers_added']:
            temp_layers_added.append(layer)
        if complet_result is not False:
            widget.setText(complet_result['path'])

        dialog.btn_run.setEnabled(True)
        dialog.btn_cancel.setEnabled(True)


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

            if del_old_layers:
                tools_qgis.remove_layer_from_toc(dxf_layer.name(), 'GW Temporal Layers')

            if toc:
                if dxf_layer.isValid():
                    self._add_layer_toc_from_dxf(dxf_layer, dxf_output_filename)
                    temp_layers_added.append(dxf_layer)

        # Unlock signals
        global_vars.iface.mainWindow().blockSignals(False)

        extras = "  "
        for widget in dialog.grb_parameters.findChildren(QWidget):
            widget_name = widget.property('columnname')
            value = tools_qt.get_text(dialog, widget, add_quote=False)
            extras += f'"{widget_name}":"{value}", '
        extras = extras[:-2]
        body = tools_gw.create_body(extras)
        result = tools_gw.execute_procedure('gw_fct_check_importdxf', None)
        if not result or result['status'] == 'Failed':
            return False

        return {"path": dxf_path, "result": result, "temp_layers_added": temp_layers_added}


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


    def _add_layer_toc_from_dxf(self, dxf_layer, dxf_output_filename):
        """  Read a dxf file and put result into TOC
        :param dxf_layer: (QgsVectorLayer)
        :param dxf_output_filename: Name of layer into TOC (string)
        :return: dxf_layer (QgsVectorLayer)
        """

        QgsProject.instance().addMapLayer(dxf_layer, False)
        root = QgsProject.instance().layerTreeRoot()
        my_group = root.findGroup(dxf_output_filename)
        if my_group is None:
            my_group = root.insertGroup(0, dxf_output_filename)
        my_group.insertLayer(0, dxf_layer)
        global_vars.canvas.refreshAllLayers()
        return dxf_layer


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