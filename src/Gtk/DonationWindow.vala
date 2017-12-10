/*
 * DonationWindow.vala
 *
 * Copyright 2012 Tony George <teejee2008@gmail.com>
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

using TeeJee.Logging;
using TeeJee.FileSystem;
using TeeJee.JSON;
using TeeJee.ProcessManagement;
using TeeJee.GtkHelper;
using TeeJee.System;
using TeeJee.Misc;

public class DonationWindow : Dialog {
	
	public DonationWindow() {
		
		set_title(_("Donate"));
		window_position = WindowPosition.CENTER_ON_PARENT;
		set_destroy_with_parent (true);
		set_modal (true);
		set_deletable(true);
		set_skip_taskbar_hint(false);
		set_default_size(400, 20);
		icon = get_app_icon(16);

		//vbox_main
		var vbox_main = get_content_area();
		vbox_main.margin = 6;
		vbox_main.margin_right = 12;
		vbox_main.homogeneous = false;

		get_action_area().visible = false;

		//lbl_message
		var lbl_message = new Gtk.Label("");
		string msg = _("Did you find this application useful?\n\nYou can buy me a coffee if you wish to say thanks, by making a donation with Paypal. Your contributions will help keep this project alive and support future development.\n\n~ Tony George (teejeetech@gmail.com)");
		lbl_message.label = msg;
		lbl_message.wrap = true;
		vbox_main.pack_start(lbl_message,true,true,0);

		//vbox_actions
		var vbox_actions = new Box (Orientation.VERTICAL, 6);
		vbox_actions.margin_left = 50;
		vbox_actions.margin_right = 50;
		vbox_actions.margin_top = 20;
		vbox_actions.margin_bottom = 10;
		vbox_main.pack_start(vbox_actions,false,false,0);

		// donate_paypal ------------------------------
		
		var button = new Button.with_label(_("Donate with PayPal"));
		vbox_actions.add(button);
		
		button.clicked.connect(()=>{
			xdg_open("https://www.paypal.com/cgi-bin/webscr?business=teejeetech@gmail.com&cmd=_xclick&currency_code=USD&amount=10&item_name=AptikBatteryMonitor%20Donation");
		});

		// home page -------------------------
		
		button = new Button.with_label(_("Project Home Page"));
		button.set_tooltip_text("https://github.com/teejee2008/battery-monitor");
		vbox_actions.add(button);
		
		button.clicked.connect(()=>{
			xdg_open("https://github.com/teejee2008/battery-monitor");
		});

		// issue tracker --------------------------
		
		button = new Button.with_label(_("Issue Tracker"));
		button.set_tooltip_text(_("Issue Tracker ~ Report Issues, Request Features, Ask Questions"));
		vbox_actions.add(button);
		
		button.clicked.connect(()=>{
			xdg_open("https://github.com/teejee2008/battery-monitor/issues");
		});

		// close -------------------------
		
		button = new Button.with_label(_("OK"));
		vbox_actions.add(button);
		
		button.clicked.connect(() => {
			this.destroy();
		});
	}
}
