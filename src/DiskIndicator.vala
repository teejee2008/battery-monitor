
using GLib;
using Gtk;
using Gee;
using Json;

using TeeJee.Logging;
using TeeJee.FileSystem;
using TeeJee.JsonHelper;
using TeeJee.ProcessHelper;
using TeeJee.GtkHelper;
using TeeJee.System;
using TeeJee.Misc;

using AppIndicator;

public class DiskIndicator: GLib.Object{
	
	protected Gee.ArrayList<Device> device_list;
    protected Indicator indicator;
    protected string icon;
    protected string name;
    protected DateTime last_refresh_date = null;
    
    public DiskIndicator(){

		App.disk_indicator = this;
		
        this.name = "Disk Manager";
        this.icon = "disks";
        this.indicator = new Indicator(
			"indicator_diskman", icon, IndicatorCategory.APPLICATION_STATUS);

		//indicator.set_status(IndicatorStatus.ACTIVE);
        
              
        indicator.set_status(IndicatorStatus.ACTIVE);
		
		refresh_tray_icon();
		
		refresh_device_list();
		
        var menu = new Gtk.Menu();

		// open -------------------------------------
		
		var item = new Gtk.ImageMenuItem.with_label(_("Open"));
        menu.append(item);
        var item_open = item;

		item.always_show_image = true;
		item.set_image(get_shared_icon("inode-directory","locked.png",16));
		item.set_reserve_indicator(false);
		
		item.activate.connect(()=>{
			var submenu = get_menu("open");
			item_open.set_submenu(submenu);
		});

		item.activate();

		// eject -------------------------------------

        /*
        item = new Gtk.MenuItem.with_label(_("Eject"));
        menu.append(item);
        var item_eject = item;

        item.activate.connect(()=>{
			var submenu = get_menu("eject");
			item_eject.set_submenu(submenu);
		});

		item.activate();
        */
        
		// mount -------------------------------------
		
        var separator = new Gtk.SeparatorMenuItem ();
		menu.add (separator);

        item = new Gtk.ImageMenuItem.with_label(_("Mount"));
        menu.append(item);
        var item_mount = item;

        item.always_show_image = true;
		item.set_image(get_shared_icon("","drive-harddisk.svg",16));
		item.set_reserve_indicator(false);

        item.activate.connect(()=>{
			var submenu = get_menu("mount");
			item_mount.set_submenu(submenu);
		});

		item.activate();

		// unmount -------------------------------------
		
        item = new Gtk.ImageMenuItem.with_label(_("Unmount"));
        menu.append(item);
        var item_unmount = item;

        item.always_show_image = true;
		item.set_image(get_shared_icon("media-eject","",16));
		item.set_reserve_indicator(false);

		item.activate.connect(()=>{
			var submenu = get_menu("unmount");
			item_unmount.set_submenu(submenu);
		});

		item.activate();

        // lock -------------------------------------
        
		separator = new Gtk.SeparatorMenuItem ();
		menu.add (separator);
		
        item = new Gtk.ImageMenuItem.with_label(_("Lock"));
        menu.append(item);
		var item_lock = item;

		item.always_show_image = true;
		item.set_image(get_shared_icon("","locked.png",16));
		item.set_reserve_indicator(false);
		
        item.activate.connect(()=>{
			var submenu = get_menu("lock");
			item_lock.set_submenu(submenu);
		});

		item.activate();

		// unlock -------------------------------------
		
        item = new Gtk.ImageMenuItem.with_label(_("Unlock"));
        menu.append(item);
		var item_unlock = item;

		item.always_show_image = true;
		item.set_image(get_shared_icon("","unlocked.png",16));
		
		item.activate.connect(()=>{
			var submenu = get_menu("unlock");
			item_unlock.set_submenu(submenu);
		});

		item.activate();
		
		// usage -------------------------------------
        
		separator = new Gtk.SeparatorMenuItem ();
		menu.add (separator);
		
        item = new Gtk.ImageMenuItem.with_label(_("Usage"));
        menu.append(item);
		var item_usage = item;

		item.always_show_image = true;
		item.set_image(get_shared_icon("disk-usage-analyzer","disk-usage-analyzer.svg",16));

        item.activate.connect(()=>{
			var submenu = get_menu("usage");
			item_usage.set_submenu(submenu);
		});

		item.activate();

		// iso -------------------------------------
        
		separator = new Gtk.SeparatorMenuItem ();
		menu.add (separator);
		
        item = new Gtk.ImageMenuItem.with_label(_("ISO"));
        menu.append(item);
		var item_iso = item;

		item.always_show_image = true;
		item.set_image(get_shared_icon("media-optical","media-optical.png",16));

        item.activate.connect(()=>{
			var submenu = get_menu("iso");
			item_iso.set_submenu(submenu);
		});

		item.activate();

		// settings -------------------------------------
        
		separator = new Gtk.SeparatorMenuItem ();
		menu.add (separator);
		
        item = new Gtk.ImageMenuItem.with_label(_("Settings"));
        menu.append(item);
		var item_settings = item;

		item.always_show_image = true;
		item.set_image(get_shared_icon("preferences-system","settings.png",16));

        item.activate.connect(()=>{
			var dlg = new SettingsWindow(null);
		});

		//item.activate();

		// about -------------------------------------
		
        separator = new Gtk.SeparatorMenuItem ();
		menu.add (separator);

		item = new Gtk.ImageMenuItem.with_label(_("About"));
        menu.append(item);

        item.activate.connect(() => {
			btn_about_clicked();
        });

        // donate -------------------------------------

        item = new Gtk.ImageMenuItem.with_label(_("Donate"));
        menu.append(item);

        item.activate.connect(() => {
            btn_donate_clicked();
        });

        // exit -------------------------------------
        
		item = new Gtk.ImageMenuItem.with_label(_("Exit"));
        menu.append(item);

        item.activate.connect(() => {
            App.exit_app();
            exit(0);
        });
       
        indicator.set_menu(menu);
		menu.show_all();
	}

	public void refresh_tray_icon(){
		if (App.use_custom_tray_icon && file_exists(App.custom_tray_icon_path)){
			log_msg("Setting custom tray icon");
			indicator.set_icon_theme_path(file_parent(App.custom_tray_icon_path));
			indicator.set_icon(file_basename(App.custom_tray_icon_path).replace(".png","").replace(".svg","").replace(".jpg","").replace(".jpeg",""));
		}
		else{
			this.icon = "disks";
			indicator.set_icon_theme_path("/usr/share/%s/images".printf(AppShortName));
			indicator.set_icon("disks");
		}
	}

	private void refresh_device_list_if_stale(){
		var period = (new DateTime.now_local()).add_seconds(-10);
		if ((device_list == null) || (last_refresh_date == null) || (last_refresh_date.compare(period) < 0)){
			device_list = Device.get_block_devices(true);
			last_refresh_date = new DateTime.now_local();
		}
	}

	private void refresh_device_list(){
		device_list = Device.get_block_devices(true);
		last_refresh_date = new DateTime.now_local();
	}
	
    private Gtk.Menu get_menu (string action = "") {

		//log_debug("get_menu(\"%s\")".printf(action));

		refresh_device_list_if_stale();
	
		var menu = new Gtk.Menu();
		menu.reserve_toggle_size = false;

		var dummy_window = new Gtk.Window();
		
		for(int i=0; i < device_list.size; i++){
			
			var dev = device_list[i];

			if (dev.size_bytes < 10 * KB){
				continue;
			}
			
			switch(action){
			case "open":
				bool show = (dev.type == "disk") || (dev.type == "loop")  || !dev.is_encrypted_partition() || !dev.has_children(); 
				if (!show){
					continue;
				}
				break;
			case "eject":
				bool show = ((dev.type == "disk") || (dev.type == "loop")) && (dev.removable); 
				if (!show){
					continue;
				}
				break;
			case "mount":
				bool show = (dev.type == "disk") || ((dev.mount_points.size == 0) && (!dev.is_encrypted_partition() || !dev.has_children())); 
				if (!show){
					continue;
				}
				break;
			case "unmount":
			case "usage":
				bool show = (dev.type == "disk")
					|| ((dev.type == "loop") && dev.has_children())
					|| (dev.mount_points.size > 0); 
				if (!show){
					continue;
				}
				break;
			case "lock":
				bool show = (dev.type == "disk") || (dev.is_on_encrypted_partition()); 
				if (!show){
					continue;
				}
				break;
			case "unlock":
				bool show = (dev.type == "disk") || (dev.is_encrypted_partition() && !dev.has_children()); 
				if (!show){
					continue;
				}
				break;

			case "iso":
				continue;
			}
			
			Gtk.Image icon = null;

			//if (action != "usage"){
				if ((dev.type == "crypt") && (dev.pkname.length > 0)){
					icon = get_shared_icon("","unlocked.png",16);
				}
				else if (dev.fstype.contains("luks")){
					icon = get_shared_icon("","locked.png",16);
				}
				else if (dev.fstype.contains("iso9660") || (dev.type == "loop")){
					icon = get_shared_icon("media-optical","media-optical.png",16);
				}
				else{
					icon = get_shared_icon("","drive-harddisk.svg",16);
				}
			//}

			var name = "";

			switch(action){
			case "usage":

				if ((dev.type == "disk") || ((dev.type == "loop") && dev.has_children())){
					name += "%s".printf(dev.description_simple());
					break;
				}
			
				name += "%s ~ %s".printf(dev.short_name_with_parent, dev.description_usage());

				if ((dev.used_bytes > 0) && (dev.size_bytes > 0)){
					double usage_percent = (dev.used_bytes * 10.0) / dev.size_bytes;
					int used_count = (int) usage_percent;
					int free_count = 10 - used_count;

					name += "  ";
					for(int j = 0; j < used_count; j++){
						name += "▮";
					}
					for(int j = 0; j < free_count; j++){
						name += "▯";
					}
				}
				else{
					name += "  ";
					for(int j = 0; j < 10; j++){
						//name += "░";░ ▒ ▓ ⬜ ⬛ ▯ ▮
					}
				}
				
				break;
				
			default:
				name += "%s".printf(dev.description_simple());
				break;
			}

			if ((dev.type != "disk") && ((action == "open") || (action == "unmount"))){
				if (dev.mount_points.size > 0){
					name += " ~ " + dev.mount_points[0].mount_point;
				}
			}

			var item = new Gtk.ImageMenuItem.with_label (name);
			item.set_reserve_indicator(false);
			menu.append(item);
			
			if (((dev.type == "loop") && dev.has_parent()) || (dev.type == "crypt") || (dev.type == "part") || (dev.type == "lvm")){
				item.always_show_image = true;
				item.set_image(icon);
			}

			/*foreach(var child in gtk_container_get_children(item)){
				//log_debug(child.get_type().to_string() + "-" + typeof(Gtk.Label).to_string());
				if (child is Gtk.Label){
					Gtk.Label label = (Gtk.Label) child;
					label.set_use_markup(true);
					label.set_markup(name);
					//log_debug("markup=%s".printf(name));
					break;
				}
			}*/

			// set sensitive ----------------------------------------
			
			switch(action){
			case "eject":
				if ((dev.type == "disk") || ((dev.type == "loop") && (dev.has_children()))){
					item.sensitive = false;
					foreach(var child in dev.children){
						if (child.has_children()){
							foreach(var decendant in child.children){
								if (decendant.mount_points.size > 0){
									item.sensitive = true;
									break;
								}
							}
						}
						else{
							if (child.mount_points.size > 0){
								item.sensitive = true;
								break;
							}
						}
					}
				}
				break;
			case "open":
			case "usage":
			case "mount":
			case "unmount":
			case "lock":
			case "unlock":
				if ((dev.type == "disk") || ((dev.type == "loop") && (dev.has_children()))){
					item.sensitive = false;
				}
				break;
			}
			
			// actions ------------------------------------------
			
			switch(action){
			case "eject":
				item.activate.connect(() => {
					
					foreach(var child in dev.children){
						
						// unmount if mounted
						if (child.mount_points.size > 0){
							bool ok = Device.unmount_udisks(child.device, dummy_window);
							if (!ok){
								return;
							}
						}

						// Note: We only need to unmount. Locking LUKS devices is not required.
						// As long as all partitions are unmounted, the device can be safely removed
					}

					string title = "%s: %s".printf(_("Unmounted"), dev.device);;
					string msg = "%s\n%s".printf(_("Disk can be safely removed"), dev.description_simple());
					OSDNotify.notify_send(title, msg, 2000, "normal", "info");

					device_list = null;
				});
				break;
				
			case "open":
				item.activate.connect(() => {

					if (dev.fstype == "swap"){
						string title = _("Swap Device!");
						string message = _("Swap devices cannot be opened in file manager");
						gtk_messagebox(title, message, null, true);
						return;
					}
							
					// unlock
					if (dev.is_encrypted_partition()){
						var dev_unlocked = luks_unlock(dev);
						if (dev_unlocked == null){
							return;
						}
						else{
							dev = dev_unlocked;
						}
					}

					// mount if unmounted
					if (dev.mount_points.size == 0){
						bool ok = Device.automount_udisks(dev.device, dummy_window);
						if (!ok){
							return;
						}
						else{
							dev = dev.query_changes();
						}
					}

					// browse
					if (dev.mount_points.size > 0){
						var mp = dev.mount_points[0];
						exo_open_folder(mp.mount_point);
					}

					device_list = null;
				});
				break;
				
			case "mount":
				item.activate.connect(() => {
					
					// mount if unmounted
					if (dev.mount_points.size == 0){
						bool ok = Device.automount_udisks(dev.device, dummy_window);
						if (!ok){
							return;
						}
						else{
							dev = dev.query_changes();
							if (dev.mount_points.size > 0){
								string title = "%s: %s".printf(_("Mounted"), dev.device);
								string msg = "%s".printf(dev.mount_points[0].mount_point);
								OSDNotify.notify_send(title, msg, 2000, "normal", "info");
							}
						}
					}
					else{
						string title = "%s: %s".printf(_("Is Mounted"), dev.device);
						string msg = "%s".printf(dev.mount_points[0].mount_point);
						OSDNotify.notify_send(title, msg, 2000, "normal", "info");
					}

					device_list = null;
				});
				break;
				
			case "unmount":
				item.activate.connect(() => {

					bool is_system = false;
					foreach (var mnt in dev.mount_points){
						switch (mnt.mount_point){
						case "/":
						case "/boot":
						case "/boot/efi":
						case "/home":
							is_system = true;
							break;
						default:
							if (dev.fstype == "swap"){
								is_system = true;
							}
							break;
						}
					}

					if (is_system){
						string title = _("System Device!");
						string message = _("System devices cannot be unmounted");
						gtk_messagebox(title, message, null, true);
						return;
					}
				
					// unmount if mounted
					if (dev.mount_points.size > 0){
						bool ok = Device.unmount_udisks(dev.device, dummy_window);
						if (!ok){
							return;
						}
						else{
							string title = "%s %s".printf(_("Unmounted"), dev.device);
							string msg = "";
							OSDNotify.notify_send(title, msg, 2000, "normal", "info");
						}
					}
					else{
						string title = "%s: %s".printf(_("Not mounted"), dev.device);
						string msg = "";
						OSDNotify.notify_send(title, msg, 2000, "normal", "info");
					}

					device_list = null;
				});
				break;
				
			case "lock":
				item.activate.connect(() => {

					bool is_system = false;
					foreach (var mnt in dev.mount_points){
						switch (mnt.mount_point){
						case "/":
						case "/boot":
						case "/boot/efi":
						case "/home":
							is_system = true;
							break;
						default:
							if (dev.fstype == "swap"){
								is_system = true;
							}
							break;
						}
					}

					if (is_system){
						string title = _("System Device!");
						string message = _("System devices cannot be unmounted");
						gtk_messagebox(title, message, null, true);
						return;
					}
					
					// unmount if mounted
					if (dev.mount_points.size > 0){
						bool ok = Device.unmount_udisks(dev.device, dummy_window);
						if (!ok){
							return;
						}
						else{
							dev = dev.query_changes();
						}
					}
					
					// lock if unlocked
					if (dev.is_on_encrypted_partition()){

						bool ok = luks_lock(dev);

						if (ok){
							string title = "%s %s".printf(_("Locked"), dev.device);
							string msg = "";
							OSDNotify.notify_send(title, msg, 2000, "normal", "info");
						}
						else{
							string title = _("Failed to lock");
							string message = App.daemon.error_message;
							gtk_messagebox(title, message, null, true);
						}
					}

					device_list = null;
				});
				break;
				
			case "unlock":
				item.activate.connect(() => {

					// unlock
					if (dev.is_encrypted_partition()){

						var dev_unlocked = luks_unlock(dev);
						
						if (dev_unlocked != null){
							string title = "%s %s".printf(_("Unlocked"), dev.device);
							string msg = "/dev/mapper/%s".printf(dev_unlocked.mapped_name);
							OSDNotify.notify_send(title, msg, 2000, "normal", "info");
						}
						else{
							string title = _("Failed to unlock");
							string message = App.daemon.error_message;
							gtk_messagebox(title, message, null, true);
						}
					}

					device_list = null;
					
				});
				break;

			case "usage":
			
				item.activate.connect(() => {
					open_baobab(dev);
				});
				
				break;
			}
		}

		// mount iso  -------------------------------------

		if (action == "iso"){
			
			var item = new Gtk.ImageMenuItem.with_label (_("Mount ISO..."));
			item.set_reserve_indicator(false);
			menu.append(item);

			item.always_show_image = true;
			var icon = get_shared_icon("media-optical","media-optical.png",16);
			item.set_image(icon);

			item.activate.connect(() => {

				var filters = new Gee.ArrayList<Gtk.FileFilter>();
				var filter = create_file_filter("All Files", { "*" });
				filters.add(filter);
				filter = create_file_filter("ISO Image File (*.iso)", { "*.iso" });
				filters.add(filter);
				var default_filter = filter;

				var selected_files = gtk_select_files(dummy_window, true, false, filters, default_filter);
				string iso_file = (selected_files.size > 0) ? selected_files[0] : "";
				if ((iso_file.length == 0) || !file_exists(iso_file)){
					return;
				}

				var loop_dev = Device.automount_udisks_iso(iso_file, dummy_window);
				
				if (loop_dev != null){

					// notify
					string title = "%s".printf(_("Mounted ISO File"));
					string msg = "%s".printf(loop_dev.device);
					OSDNotify.notify_send(title, msg, 2000, "normal", "info");

					if (loop_dev.has_children()){
						// get first iso9660 partition
						var list = Device.get_block_devices_using_lsblk();
						foreach(var dev in list){
							if ((dev.pkname == loop_dev.device.replace("/dev/","")) && (dev.fstype == "iso9660")){
								loop_dev = dev;
								break;
							}
						}
					}
					
					// browse
					if (loop_dev != null){
						var mps = Device.get_device_mount_points(loop_dev.device);
						if (mps.size > 0){
							var mp = mps[0];
							exo_open_folder(mp.mount_point);
						}
					}
				}
			});
		}

		menu.show_all();
		
		return menu;
	}

	private Device? luks_unlock(Device dev_locked){

		var dev = dev_locked;
		
		if (!dev.is_encrypted_partition()){
			log_error("luks_unlock: is_encrypted_partition(): false");
			return null;
		}

		var dummy_window = new Gtk.Window();
		
		App.init_daemon();

		while (!App.daemon.is_ready){
			sleep(100);
		}

		log_debug("Prompting user for passphrase..");
		
		var password = gtk_inputbox(
				_("Encrypted Device"),
				_("Enter passphrase to unlock '%s'").printf(dev.device),
				dummy_window, true);

		if (password == null){
			log_debug("User cancelled the password prompt");
			return null;
		}

		string cmd = "luks_unlock|%s|%s".printf(dev.device, password);
		App.daemon.send_command(cmd);

		Device dev_unlocked = null;
		dev = dev.query_changes();
		if (dev.has_children()){
			dev_unlocked = dev.children[0];
		}

		return dev_unlocked;
	}

	private bool luks_lock(Device dev_unlocked){

		Device dev_luks = null;
		if (dev_unlocked.is_on_encrypted_partition()){
			dev_luks = dev_unlocked;
		}
		else if (dev_unlocked.is_encrypted_partition() && (dev_unlocked.has_children())){
			dev_luks = dev_unlocked.children[0];
		}

		App.init_daemon();

		while (!App.daemon.is_ready){
			sleep(100);
		}

		string cmd = "luks_lock|%s".printf(dev_luks.device);
		int status = App.daemon.send_command(cmd);
		return (status == 0);
	}

	private void open_baobab(Device dev){

		if ((dev.used_bytes > 0) && (dev.mount_points.size > 0)){
			string cmd = "baobab '%s'\n".printf(dev.mount_points[0].mount_point);
			string std_out, std_err;
			exec_script_sync(cmd, out std_out, out std_err, false, true);
		}
		
		/*if ((dev.used_bytes > 0) && (dev.mount_points.size > 0)){
			
			App.init_daemon();

			while (!App.daemon.is_ready){
				sleep(100);
			}

			string cmd = "open_baobab|%s".printf(dev.mount_points[0].mount_point);
			App.daemon.send_command(cmd);
		}*/
	}

	public void btn_donate_clicked(){
		var dialog = new DonationWindow();
		//dialog.set_transient_for(this);
		dialog.show_all();
		dialog.run();
		dialog.destroy();
	}

	private void btn_about_clicked (){
		
		var dialog = new AboutWindow();
		//dialog.set_transient_for(this);

		dialog.authors = {
			"Tony George:teejeetech@gmail.com"
		};

		dialog.translators = {

		};

		dialog.contributors = {

		};

		dialog.third_party = {

		};

		dialog.documenters = null;
		dialog.artists = null;
		dialog.donations = null;

		dialog.program_name = AppName;
		dialog.comments = _("Disk Indicator for Linux");
		dialog.copyright = "Copyright © 2016 Tony George (%s)".printf(AppAuthorEmail);
		dialog.version = AppVersion;
		dialog.logo = get_shared_icon_pixbuf("disks","disks.png", 128);

		dialog.license = "This program is free for personal and commercial use and comes with absolutely no warranty. You use this program entirely at your own risk. The author will not be liable for any damages arising from the use of this program.";
		dialog.website = "http://teejeetech.in";
		dialog.website_label = "http://teejeetech.blogspot.in";

		dialog.initialize();
		dialog.show_all();
	}
	
}

