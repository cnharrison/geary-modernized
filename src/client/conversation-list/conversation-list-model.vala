/*
 * Copyright © 2022 John Renner <john@jrenner.net>
 * Copyright © 2022 Cédric Bellegarde <cedric.bellegarde@adishatz.org>
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later). See the COPYING file in this distribution.
 */

public enum ConversationList.FilterMode {
    ALL,
    UNREAD,
    STARRED
}

// The whole goal of this class to wrap the ConversationMonitor with a view that presents a sorted list
public class ConversationList.Model : Object, ListModel {
    internal GLib.GenericArray<Geary.App.Conversation> items = new GLib.GenericArray<Geary.App.Conversation>();
    private GLib.GenericArray<Geary.App.Conversation> loaded_items = new GLib.GenericArray<Geary.App.Conversation>();
    private Gee.List<FlagSignalBinding> flag_signal_bindings =
        new Gee.ArrayList<FlagSignalBinding>();
    private Geary.Folder? retained_source_folder = null;
    private string? retained_account_context = null;
    internal ConversationSource source { get; set; }

    internal Geary.App.Conversation? retained_conversation {
        get { return this._retained_conversation; }
        set {
            if (this._retained_conversation != value) {
                bool rebuild = (
                    this._retained_conversation != null &&
                    !matches_filter_mode(this._retained_conversation)
                ) || (value != null && !matches_filter_mode(value));
                release_retained_conversation();
                this._retained_conversation = value;
                if (rebuild) {
                    rebuild_items();
                }
            }
        }
    }
    private Geary.App.Conversation? _retained_conversation = null;

    public FilterMode filter_mode {
        get { return this._filter_mode; }
        set {
            if (this._filter_mode != value) {
                release_retained_conversation();
                this._filter_mode = value;
                rebuild_items();
                notify_property("filter-mode");
            }
        }
    }
    private FilterMode _filter_mode = ALL;

    public bool can_load_more {
        get { return this.source.can_load_more; }
    }

    private bool scanning = false;

    internal Model(ConversationSource source) {
        this.source = source;

        source.conversations_added.connect(on_conversations_added);
        source.conversation_appended.connect(on_conversation_updated);
        source.conversation_trimmed.connect(on_conversation_updated);
        source.conversations_removed.connect(on_conversations_removed);
        source.scan_started.connect(on_scan_started);
        source.scan_completed.connect(on_scan_completed);
    }

    ~Model() {
        this.source.conversations_added.disconnect(on_conversations_added);
        this.source.conversation_appended.disconnect(on_conversation_updated);
        this.source.conversation_trimmed.disconnect(on_conversation_updated);
        this.source.conversations_removed.disconnect(on_conversations_removed);
        this.source.scan_started.disconnect(on_scan_started);
        this.source.scan_completed.disconnect(on_scan_completed);
        disconnect_all_conversations();
    }

    public signal void conversations_added(bool start);
    public signal void conversations_removed(bool start);
    public signal void conversations_loaded();
    public signal void conversation_updated(Geary.App.Conversation convo);

    internal Geary.Folder get_source_folder(Geary.App.Conversation conversation) {
        if (conversation == this._retained_conversation &&
            this.retained_source_folder != null) {
            return this.retained_source_folder;
        }
        return this.source.get_source_folder(conversation);
    }

    internal string get_account_context(Geary.App.Conversation conversation) {
        if (conversation == this._retained_conversation &&
            this.retained_source_folder != null) {
            assert(this.retained_account_context != null);
            return this.retained_account_context;
        }
        return this.source.get_account_context(conversation);
    }

    private static int compare(Object a, Object b) {
        return Util.Email.compare_conversation_descending(a as Geary.App.Conversation, b as Geary.App.Conversation);
    }

    // ------------------------
    //  Scanning and load_more
    // ------------------------

    private void on_scan_started(ConversationSource source) {
        this.scanning = true;
    }

    private void on_scan_completed(ConversationSource source) {
        this.scanning = false;
        GLib.Timeout.add(100, () => {
            if (!this.scanning) {
                conversations_loaded();
            }
            return false;
        });
    }

    public bool load_more(int amount) {
        if (this.scanning || !this.can_load_more) {
            return false;
        }

        this.source.min_window_count += amount;
        return true;
    }


    // ------------------------
    // Model
    // ------------------------

    public Object? get_item(uint position) {
        return this.items.get(position);
    }

    public Type get_item_type() {
        return typeof(Geary.App.Conversation);
    }

    public uint get_n_items() {
        return this.items.length;
    }

    private bool insert_conversation(Geary.App.Conversation convo) {
        // The conversation may be bogus, if so don't do anything
        Geary.Email? last_email = convo.get_latest_recv_email(Geary.App.Conversation.Location.ANYWHERE);

        if (last_email == null) {
            debug("Cannot add conversation: last email is null");
            return false;
        }

        if (this.loaded_items.find(convo)) {
            if (convo == this._retained_conversation &&
                this.retained_source_folder != null) {
                clear_retained_source();
            }
            return false;
        }

        this.loaded_items.add(convo);
        connect_conversation(convo);

        return true;
    }

    private bool matches_filter(Geary.App.Conversation conversation) {
        return conversation == this._retained_conversation ||
            matches_filter_mode(conversation);
    }

    private bool matches_filter_mode(Geary.App.Conversation conversation) {
        switch (this.filter_mode) {
        case ALL:
            return true;

        case UNREAD:
            return conversation.is_unread();

        case STARRED:
            return conversation.is_flagged();

        default:
            assert_not_reached();
        }
    }

    private void release_retained_conversation() {
        Geary.App.Conversation? retained = this._retained_conversation;
        bool remove = this.retained_source_folder != null;

        this._retained_conversation = null;
        clear_retained_source();

        if (remove && retained != null) {
            remove_conversation(retained);
        }
    }

    private void clear_retained_source() {
        this.retained_source_folder = null;
        this.retained_account_context = null;
    }

    private bool remove_conversation(Geary.App.Conversation conversation) {
        if (!this.loaded_items.remove(conversation)) {
            return false;
        }

        disconnect_conversation(conversation);
        if (conversation == this._retained_conversation) {
            this._retained_conversation = null;
            clear_retained_source();
        }
        return true;
    }

    private void rebuild_items() {
        GLib.GenericArray<Geary.App.Conversation> old_items = this.items;
        var new_items = new GLib.GenericArray<Geary.App.Conversation>();
        for (uint i = 0; i < this.loaded_items.length; i++) {
            Geary.App.Conversation conversation = this.loaded_items.get(i);
            if (matches_filter(conversation)) {
                new_items.add(conversation);
            }
        }
        new_items.sort(compare);

        uint prefix = 0;
        while (prefix < old_items.length && prefix < new_items.length &&
               old_items.get(prefix) == new_items.get(prefix)) {
            prefix++;
        }

        uint suffix = 0;
        while (suffix < old_items.length - prefix &&
               suffix < new_items.length - prefix &&
               old_items.get(old_items.length - suffix - 1) ==
                   new_items.get(new_items.length - suffix - 1)) {
            suffix++;
        }

        this.items = new_items;
        uint removed = old_items.length - prefix - suffix;
        uint added = new_items.length - prefix - suffix;
        if (removed > 0 || added > 0) {
            this.items_changed(prefix, removed, added);
        }
    }

    private void connect_conversation(Geary.App.Conversation conversation) {
        if (get_flag_signal_binding(conversation) == null) {
            this.flag_signal_bindings.add(
                new FlagSignalBinding(
                    conversation,
                    conversation.email_flags_changed.connect(
                        on_conversation_flags_changed
                    )
                )
            );
        }
    }

    private void disconnect_conversation(Geary.App.Conversation conversation) {
        FlagSignalBinding? binding = get_flag_signal_binding(conversation);
        if (binding != null) {
            if (GLib.SignalHandler.is_connected(
                binding.conversation, binding.signal_id
            )) {
                binding.conversation.disconnect(binding.signal_id);
            }
            this.flag_signal_bindings.remove(binding);
        }
    }

    private void disconnect_all_conversations() {
        while (!this.flag_signal_bindings.is_empty) {
            disconnect_conversation(this.flag_signal_bindings[0].conversation);
        }
    }

    private FlagSignalBinding? get_flag_signal_binding(
        Geary.App.Conversation conversation
    ) {
        foreach (FlagSignalBinding binding in this.flag_signal_bindings) {
            if (binding.conversation == conversation) {
                return binding;
            }
        }
        return null;
    }

    private void on_conversation_flags_changed(Geary.Email email) {
        rebuild_items();
    }

    private class FlagSignalBinding {
        public Geary.App.Conversation conversation;
        public ulong signal_id;

        public FlagSignalBinding(Geary.App.Conversation conversation,
                                 ulong signal_id) {
            this.conversation = conversation;
            this.signal_id = signal_id;
        }
    }

    private void on_conversations_added(Gee.Collection<Geary.App.Conversation> conversations) {
        debug("Adding %d conversations.", conversations.size);

        conversations_added(true);

        var added = 0;
        foreach (Geary.App.Conversation convo in conversations) {
            if (insert_conversation(convo)) {
                added++;
            }
        }
        rebuild_items();

        conversations_added(false);

        debug("Added %d/%d conversations.", added, conversations.size);
    }

    private void on_conversations_removed(Gee.Collection<Geary.App.Conversation> conversations) {
        debug("Removing %d conversations.", conversations.size);

        conversations_removed(true);

        var removed = 0;
        foreach (Geary.App.Conversation convo in conversations) {
            if (convo == this._retained_conversation &&
                !matches_filter_mode(convo)) {
                if (this.retained_source_folder == null) {
                    this.retained_source_folder = this.source.get_source_folder(convo);
                    this.retained_account_context = this.source.get_account_context(convo);
                }
            } else if (remove_conversation(convo)) {
                removed++;
            }
        }

        rebuild_items();

        conversations_removed(false);

        debug("Removed %ld/%d conversations.", removed, conversations.size);
    }

    private void on_conversation_updated(ConversationSource sender, Geary.App.Conversation convo, Gee.Collection<Geary.Email> emails) {
        conversation_updated(convo);

        if (this.loaded_items.find(convo)) {
            rebuild_items();
        }
    }
}
