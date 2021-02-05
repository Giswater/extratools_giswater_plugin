"""
This file is part of Giswater 3
The program is free software: you can redistribute it and/or modify it under the terms of the GNU
General Public License as published by the Free Software Foundation, either version 3 of the License,
or (at your option) any later version.
"""
# -*- coding: utf-8 -*-

from qgis.PyQt.QtWidgets import QComboBox, QCheckBox, QDoubleSpinBox, QSpinBox, QWidget, QLineEdit
from qgis.PyQt.QtCore import pyqtSignal
from qgis.core import QgsTask
from qgis.gui import QgsDateTimeEdit

from ...settings import task, tools_qgis, tools_qt, tools_gw, tools_db, toolbox, tools_os, tools_log

import time
class GwDxfExtraTool(task.GwTask):
    """ This shows how to subclass QgsTask """

    task_finished = pyqtSignal(list)

    def __init__(self, description, dialog):

        super().__init__(description, QgsTask.CanCancel)
        # self.toolbox = toolbox
        self.dialog = dialog
        # self.combo = combo
        # self.result = result
        self.json_result = None
        self.exception = None

    def run(self):

        state = tools_qt.get_combo_value(self.dialog, self.dialog.cmb_state, 0)
        state_type = tools_qt.get_combo_value(self.dialog, self.dialog.cmb_state_type, 0)
        workcat = tools_qt.get_combo_value(self.dialog, self.dialog.cmb_workcat, 0)
        arc_type = tools_qt.get_combo_value(self.dialog, self.dialog.cmb_arc_type, 0)
        node_type = tools_qt.get_combo_value(self.dialog, self.dialog.cmb_node_type, 0)
        topocontrol = tools_qt.is_checked(self.dialog, self.dialog.chk_topocontrol)
        extras = f'"parameters":{{"state":"{state}", "state_type":"{state_type}", "workcat":"{workcat}", ' \
                 f'"arc_type":"{arc_type}", "node_type":"{node_type}", "topocontrol":"{topocontrol}"}}'
        body = tools_gw.create_body(extras=extras)
        self.json_result = tools_gw.execute_procedure('gw_fct_insert_importdxf', body, log_sql=True, is_thread=True)
        try:
            if self.json_result['status'] == 'Failed': return False
            if not self.json_result or self.json_result is None: return False

            # getting simbology capabilities
            if 'setStyle' in self.json_result['body']['data']:
                set_sytle = self.json_result['body']['data']['setStyle']
                if set_sytle == "Mapzones":
                    # call function to simbolize mapzones
                    tools_gw.set_style_mapzones()

        except KeyError as e:
            self.exception = e
            return False
        return True

    def finished(self, result):
        if result is False and self.exception is not None:
            msg = f"<b>Key: </b>{self.exception}<br>"
            msg += f"<b>key container: </b>'body/data/ <br>"
            msg += f"<b>Python file: </b>{__name__} <br>"
            msg += f"<b>Python function:</b> {self.__class__.__name__} <br>"
            tools_qt.show_exception_message("Key on returned json from ddbb is missed.", msg)
        elif result:
            tools_gw.fill_tab_log(self.dialog, self.json_result['body']['data'], True, True, 1, True, False)

    def cancel(self):
        super().cancel()