/*
 * PackageManagerWindow.vala
 *
 * Copyright 2015 Tony George <teejee2008@gmail.com>
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

public class BatteryStatsWindow : Window {
	private Box vbox_main;
	private Box hbox_stats_line1;
	private Box hbox_stats_line2;
	private Box hbox_top_line1;
	private CheckButton chk_enable;

	private Gtk.DrawingArea drawing_area;

	private Label lbl_date_val;
	private Label lbl_charge_val;
	private Label lbl_voltage_val;
	private Label lbl_cpu_val;
	private Label lbl_discharge_val;

	BatteryStat stat_current;
	int X_INTERVAL = 5;
	int X_OFFSET = 30;
	int Y_OFFSET = 20;

	uint timer_refresh = 0;

	int def_width = 400;
	int def_height = 400;

	public BatteryStatsWindow() {
		destroy.connect(Gtk.main_quit);
		init_window();
	}

	public BatteryStatsWindow.with_parent(Window parent) {
		set_transient_for(parent);
		set_modal(true);
		init_window();
		init_window_for_parent();
	}

	public void init_window () {
		title = "Aptik Battery Monitor" + " v" + AppVersion;
    window_position = WindowPosition.CENTER;
    resizable = true;
    set_default_size (def_width, def_height);

		//vbox_main
    vbox_main = new Box (Orientation.VERTICAL, 6);
    vbox_main.margin = 6;
    add (vbox_main);

		init_header();

		init_graph();

		init_stats();

		show_all();

		//TODO: Should start if not already running

		timer_refresh = Timeout.add(30 * 1000, timer_refresh_graph);
	}

	public void init_window_for_parent(){
		//btn_actions.hide();
		//btn_selections.hide();
	}

	public void init_header(){
		hbox_top_line1 = new Box (Orientation.HORIZONTAL, 6);
		//hbox_stats_line1.margin = 6;
		vbox_main.add (hbox_top_line1);

		chk_enable = new CheckButton.with_label (_("Enable logging"));
		//chk_enable.margin_left = 6;
		hbox_top_line1.add(chk_enable);

		chk_enable.active = (App.is_logging_enabled());

		chk_enable.clicked.connect (() => {
			App.set_battery_monitoring_status(chk_enable.active);
		});

		var lbl_spacer = new Label("");
		lbl_spacer.hexpand = true;
		hbox_top_line1.add(lbl_spacer);

		//btn_donate
    var btn_donate = new Gtk.Button.from_stock ("gtk-missing-image");
		btn_donate.label = _("Donate");
		//btn_donate.label = "";
		btn_donate.set_tooltip_text (_("Donate"));
		//btn_donate.image = get_shared_icon("donate","donate.svg",16);
		//btn_donate.always_show_image = true;
		//btn_donate.image_position = PositionType.RIGHT;
    hbox_top_line1.add(btn_donate);

		btn_donate.clicked.connect(()=>{
			var dialog = new DonationWindow();
			dialog.set_transient_for(this);
			dialog.show_all();
			dialog.run();
			dialog.destroy();
			});

		//btn_about
    var btn_about = new Gtk.Button.from_stock ("gtk-about");
		btn_about.label = _("Info");
		//btn_about.label = "";
		btn_about.set_tooltip_text (_("Application Info"));
		//btn_about.image = get_shared_icon("gtk-about","help-info.svg",16);
		//btn_about.always_show_image = true;
		//btn_about.image_position = PositionType.RIGHT;
    hbox_top_line1.add(btn_about);

    btn_about.clicked.connect (btn_about_clicked);
	}

	private void btn_about_clicked (){
		var dialog = new AboutWindow();
		dialog.set_transient_for (this);

		dialog.authors = {
			"Tony George:teejeetech@gmail.com"
		};

		dialog.translators = {
			//"giulux (Italian)",
			//"Jorge Jamhour (Brazilian Portuguese):https://launchpad.net/~jorge-jamhour",
			//"B. W. Knight (Korean):https://launchpad.net/~kbd0651",
			//"Rodion R. (Russian):https://launchpad.net/~r0di0n"
		};

		dialog.documenters = null;
		dialog.artists = null;
		dialog.donations = null;

		dialog.program_name = AppName;
		dialog.comments = _(" A Battery Monitoring Utility for Laptops");
		dialog.copyright = "Copyright © 2015 Tony George (%s)".printf(AppAuthorEmail);
		dialog.version = AppVersion;
		dialog.logo = get_app_icon(128);

		dialog.license = "This program is free for personal and commercial use and comes with absolutely no warranty. You use this program entirely at your own risk. The author will not be liable for any damages arising from the use of this program.";
		dialog.website = "http://teejeetech.in";
		dialog.website_label = "http://teejeetech.blogspot.in";

		dialog.initialize();
		dialog.show_all();
	}

	public void init_graph(){
		drawing_area = new Gtk.DrawingArea();
		drawing_area.set_size_request(400,200);
		drawing_area.margin = 10;

		var sw_graph = new ScrolledWindow(null, null);
		sw_graph.set_shadow_type (ShadowType.ETCHED_IN);
		sw_graph.expand = true;

		sw_graph.add (drawing_area);
		vbox_main.add(sw_graph);

		App.read_battery_stats();

		drawing_area.add_events(Gdk.EventMask.BUTTON_PRESS_MASK);

		drawing_area.button_press_event.connect((event)=> {
			BatteryStat stat_prev = null;
			foreach(var stat in App.battery_stats_list){
				if (stat.date == null) { continue; }

				if (Math.fabsf((float)(stat.graph_x - event.x)) < X_INTERVAL){
					stat_current = stat;
					lbl_date_val.label = stat.date.format("%d %b %Y, %I:%M %p"); //%F %H:%M:%S
					//lbl_charge_val.label = "%ld, %ld".printf(stat.charge_now, BatteryStat.batt_charge_full());
					lbl_charge_val.label = "%0.2f%%, %0.0f mAh, %0.2f Wh".printf(
						stat.charge_percent(),
						stat.charge_in_mah(),
						stat.charge_in_wh()
						);
					lbl_voltage_val.label = "%0.2f V".printf(stat.voltage());
					lbl_cpu_val.label = "%0.2f %%".printf(stat.cpu_percent());
					if (stat_prev != null){
						double rate = (stat_prev.charge_percent() - stat.charge_percent()) * 2 * 60;
						double estimated = 100/rate;
						lbl_discharge_val.label = "%0.2f%/hr, %0.1f hrs".printf(rate,estimated);
					}
				}
				stat_prev = stat;
			}
			redraw_graph_area();
			return true;
		});

		drawing_area.draw.connect ((context) => {
			// Get necessary data:
			weak Gtk.StyleContext style_context = drawing_area.get_style_context ();

			var color_default = style_context.get_color (0);

			var color_white = Gdk.RGBA();
			color_white.parse("white");
			color_white.alpha = 1.0;

			var color_black = Gdk.RGBA();
			color_black.parse("black");
			color_black.alpha = 1.0;

			var color_red = Gdk.RGBA();
			color_red.parse("red");
			color_red.alpha = 1.0;

			var color_blue = Gdk.RGBA();
			color_blue.parse("blue");
			color_blue.alpha = 1.0;

			color_default = color_black;

			Gdk.cairo_set_source_rgba (context, color_default);
			context.set_line_width (1);

			int stat_count = (App.battery_stats_list.size > 2880) ? 2880 : App.battery_stats_list.size;

			int w = drawing_area.get_allocated_width();
			int h = drawing_area.get_allocated_height();

			//int w_eff = w - X_OFFSET;
			int h_eff = h - 2 * Y_OFFSET;

			//double pxw = (w_eff / 100.00);
			double pxh = (h_eff / 100.00);

			long x0 = X_OFFSET;
			long y0 = h - Y_OFFSET;
			long x100 = x0 + (stat_count * X_INTERVAL);
			long y100 = Y_OFFSET;

			long x, x_prev, y, y_prev, y_cpu, y_prev_cpu;
			x = x_prev = x0;
			y = y_prev = y_cpu = y_prev_cpu = y0;

			int count = 0;
			BatteryStat stat_prev = null;
			int count_24_hours = 2880;

			foreach(var stat in App.battery_stats_list){
				if (stat.date == null) { continue; }
				count++;

				if (App.battery_stats_list.size > count_24_hours){
					if (count < (App.battery_stats_list.size - 2880)) {
						//ignore entries older than latest 2880 records
						continue;
					}
				}

				x += X_INTERVAL;
				stat.graph_x = x;

				//------ BEGIN CONTEXT -------------------------------------------------
				context.set_line_width (1);
				Gdk.cairo_set_source_rgba (context,color_default);

				//draw X-axis marker and label for stat -----------------

				if (((stat.date.get_minute() % 10) == 0)&&(stat.date.get_second() < 30)){
					//draw X-axis markers
					context.move_to(x, y0-2);
					context.line_to(x, y0+2);
					//draw X-axis labels
					context.move_to (x - 15, h - Y_OFFSET + 20);
					context.show_text(stat.date.format("%I:%M %p"));
				}

				context.stroke ();
				//------ END CONTEXT ---------------------------------------------------

				if (stat_prev != null){
					if (stat_prev.date.add_seconds(Main.BATT_STATS_LOG_INTERVAL + 1).compare(stat.date) < 0){

						//------ BEGIN CONTEXT -------------------------------------------
						context.set_line_width (0.5);
						Gdk.cairo_set_source_rgba (context,color_default);

						//draw a vertical line
						context.move_to(x_prev, y0);
						context.line_to(x_prev, y100);

						//draw a vertical line
						context.move_to(x, y0);
						context.line_to(x, y100);

						context.stroke ();
						//------ END CONTEXT -----------------------------------------
					}
					else{
						//------ BEGIN CONTEXT -------------------------------------------
						context.set_line_width (0.5);
						Gdk.cairo_set_source_rgba (context,color_default);

						for(int p = 10; p <= 100; p+=10){
							long y_interval = (long) (h - Y_OFFSET - (p * pxh));
							//draw Y-axis lines
							context.move_to(x_prev, y_interval);
							context.line_to(x, y_interval);
						}

						context.stroke ();
						//------ END CONTEXT ---------------------------------------------

						//------ BEGIN CONTEXT -------------------------------------------
						context.set_line_width (1);
						Gdk.cairo_set_source_rgba (context,color_default);

						//draw battery line for stat ---------------------------

						context.move_to (x_prev, y_prev);

						y = (long) ((stat.charge_now * 100.00 * pxh) / BatteryStat.batt_charge_full());
						y = h - Y_OFFSET - y;

						context.line_to (x, y);

						context.stroke ();
						//------ END CONTEXT ---------------------------------------------

						//------ BEGIN CONTEXT -------------------------------------------
						context.set_line_width (1);
						Gdk.cairo_set_source_rgba (context,color_red);

						//draw cpu line for stat ----------------

						context.move_to (x_prev, y_prev_cpu);

						y_cpu = (long) (stat.cpu_percent() * pxh);
						y_cpu = h - Y_OFFSET - y_cpu;
						context.line_to (x, y_cpu);

						y_prev_cpu = y_cpu;

						context.stroke ();
						//------ END CONTEXT ---------------------------------------------
					}
				}

				if ((stat_current != null) && (stat_current.date == stat.date)){
						//------ BEGIN CONTEXT -------------------------------------------
					context.set_line_width (0.5);
					Gdk.cairo_set_source_rgba (context, color_blue);
					//draw a vertical line for selected stat
					context.move_to(x, y0);
					context.line_to(x, y100);
					context.stroke ();
						//------ END CONTEXT ---------------------------------------------
				}

				stat_prev = stat;
				if (stat_current == null){
					stat_current = stat;
				}
				x_prev = x;
				y_prev = y;
			}

			//------ BEGIN CONTEXT -------------------------------------------------

			context.set_line_width (1);
			Gdk.cairo_set_source_rgba (context,color_default);

			//draw axis lines -----------------------------

			//draw X-axis line
			context.move_to(x0,   y0);
			context.line_to(x100, y0);

			//draw Y-axis line
			context.move_to(x0, y0);
			context.line_to(x0, y100);

			context.stroke ();

			//------ END CONTEXT ---------------------------------------------------

			//------ BEGIN CONTEXT -------------------------------------------------
			context.set_line_width (0.5);

			//draw Y-axis markers and labels ------------------------

			for(int p = 10; p <= 100; p+=10){
				y = (long) (h - Y_OFFSET - (p * pxh));

				//draw Y-axis markers
				context.move_to(x0+2, y);
				context.line_to(x0-2, y);

				/*
				//draw Y-axis lines
				context.move_to(x0,   y);
				context.line_to(x100, y);
				*/

				//draw Y-axis labels
				context.move_to (x0 - X_OFFSET, y);
				context.show_text("%d%%".printf(p));
			}

			context.stroke ();
			//------ END CONTEXT ---------------------------------------------------

			drawing_area.set_size_request((X_INTERVAL * stat_count) + (2 * X_OFFSET),-1);

			return true;
		});
	}

	public void init_stats(){
		hbox_stats_line1 = new Box (Orientation.HORIZONTAL, 6);
    //hbox_stats_line1.margin = 6;
    vbox_main.add (hbox_stats_line1);

	 	var lbl_date = new Label("<b>" + ("Date") + ":</b>");
		lbl_date.set_use_markup(true);
		hbox_stats_line1.add(lbl_date);

		lbl_date_val = new Label(_("25 Aug 2015, 10:35:16 PM"));
		hbox_stats_line1.add(lbl_date_val);

		var lbl_charge = new Label("<b>" + ("Charge") + ":</b>");
		lbl_charge.set_use_markup(true);
		hbox_stats_line1.add(lbl_charge);

		lbl_charge_val = new Label(_("17.58%, 6200 mAh, 57.14 Wh"));
		hbox_stats_line1.add(lbl_charge_val);

		var lbl_voltage = new Label("<b>" + ("Voltage") + ":</b>");
		lbl_voltage.set_use_markup(true);
		hbox_stats_line1.add(lbl_voltage);

		lbl_voltage_val = new Label(_("8700 mV"));
		hbox_stats_line1.add(lbl_voltage_val);

		hbox_stats_line2 = new Box (Orientation.HORIZONTAL, 6);
    //hbox_stats_line2.margin = 6;
    vbox_main.add (hbox_stats_line2);

		var lbl_discharge = new Label("<b>" + ("Discharge Rate") + ":</b>");
		lbl_discharge.set_use_markup(true);
		hbox_stats_line2.add(lbl_discharge);

		lbl_discharge_val = new Label(_("17.58%/hr, 8:10 hrs"));
		hbox_stats_line2.add(lbl_discharge_val);

		var lbl_cpu = new Label("<b>" + ("CPU") + ":</b>");
		lbl_cpu.set_use_markup(true);
		hbox_stats_line2.add(lbl_cpu);

		lbl_cpu_val = new Label(_("2%"));
		hbox_stats_line2.add(lbl_cpu_val);

		//TODO: Show values in color
		//TODO: Show legends

		//show empty values
		lbl_date_val.label = (new DateTime.now_local()).format("%d %b %Y, %I:%M %p"); //%F %H:%M:%S
		lbl_charge_val.label = "%0.2f%%, %0.0f mAh, %0.2f Wh".printf(0.0,0.0,0.0);
		lbl_voltage_val.label = "%0.2f V".printf(0.0);
		lbl_cpu_val.label = "%0.2f %%".printf(0.0);
		lbl_discharge_val.label = "00.00%/hr, 0.0 hrs";
	}

	public bool timer_refresh_graph(){
		//if (timer_pkg_info > 0){
		//	Source.remove(timer_pkg_info);
		//	timer_pkg_info = 0;
		//}

		if (chk_enable.active){
			App.read_battery_stats();
			redraw_graph_area();
		}

		return true;
	}

	private void redraw_graph_area(){
		drawing_area.queue_draw_area(0,0,
			drawing_area.get_allocated_width(),
			drawing_area.get_allocated_height());
	}
}
