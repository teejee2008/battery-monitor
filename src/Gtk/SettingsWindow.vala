/*
 * SettingsWindow.vala
 *
 * Copyright 2012-2017 Tony George <teejeetech@gmail.com>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
 * MA 02110-1301, USA.
 *
 *
 */


using Gtk;
using Gee;

using TeeJee.Logging;
using TeeJee.FileSystem;
using TeeJee.JSON;
using TeeJee.ProcessManagement;
using TeeJee.GtkHelper;
using TeeJee.Multimedia;
using TeeJee.System;
using TeeJee.Misc;

public class SettingsWindow : Dialog {

	private Gtk.Switch switch_show_bar;
	
	public SettingsWindow() {
		//set_size_request(500, 300);
		set_title(_("Settings"));
		window_position = WindowPosition.CENTER_ON_PARENT;
		set_destroy_with_parent (true);
		set_modal (true);
		set_deletable(true);
		set_skip_taskbar_hint(true);
		icon = get_app_icon(16);

		//vbox_main
		Box vbox_main = get_content_area();
		vbox_main.margin = 6;
		vbox_main.homogeneous = false;

		var hbox_show_bar = new Box (Orientation.HORIZONTAL, 6);
		hbox_show_bar.margin = 6;
		vbox_main.add (hbox_show_bar);

		//lbl_message
		Label lbl_bar_enable = new Gtk.Label(_("Show battery bar"));
		hbox_show_bar.add(lbl_bar_enable);

		//switch_show_bar
		switch_show_bar = new Gtk.Switch();
		switch_show_bar.halign = Align.END;
		//switch_show_bar.active = App.is_battery_bar_enabled();
		hbox_show_bar.add(switch_show_bar);

		switch_show_bar.notify["active"].connect(() => {
			//App.set_battery_bar_status_cron(switch_show_bar.active);
		});

		var hbox_action = (Box) get_action_area();

		//btn_close
		var btn_close = new Button.with_label("  " + _("OK"));
		btn_close.set_image (new Image.from_stock ("gtk-ok", IconSize.MENU));
		hbox_action.add(btn_close);

		btn_close.clicked.connect(()=>{ this.destroy(); });
	}
}


