# Audit UI «Anello» (2026-10-23)

Analisi in sola lettura di `lib/ui/screens` (grep dei segni del vecchio aspetto e dei widget di casa; stato stimato dai conteggi, non da una verifica visiva). I pacchetti in fondo sono diventati i passi 36.R1–36.R8 di `PROGRESS.md`.

Anello audit of lib/ui/screens (read-only). Base for every path below: lib/ui/screens/

Method: grepped every file for old-look markers (AppBar, SegmentedButton, RadioListTile, ChoiceChip/FilterChip, Card, colorScheme, Colors., CircularProgressIndicator, showModalBottomSheet, AlertDialog) and house markers (context.cc, CcDims, CollectionScaffold/Header, EmptyState, ErrorState, SegmentedBlocks, SectionHeader, CcSheet, TrackRow). Plans' "Files:" lists were checked for what was touched. Status is a judgment from those counts, not a visual check. Caveat: "Card(" also matches AlbumCard/ArtistCard/TopArtistsCard (false positive); "' · '" hits are doc comments only, so no separator strings are left in UI code. The plan 2.3 path lib/ui/screens/import/sync_preview_dialog.dart does not exist; the real file is share/sync_preview_dialog.dart.

| file(s) | redesigned | gaps |
|---|---|---|
| **activity/** activity_sheet | yes | none |
| activity/activity_log_screen | partial | plain AppBar, no CollectionHeader |
| **car/** car_mode_screen | yes | none seen |
| car/car_playlists_sheet | no | raw showModalBottomSheet, no CcSheet |
| **cleanup/** duplicates_screen | partial | AppBar; Card in the list; ConstrainedBox 520 on desktop |
| cleanup/duplicate_group_card, duplicate_member_row | partial/no | Card; dialog-style row |
| cleanup/hidden_tracks_screen, tag_backups_screen | partial | AppBar titles (EmptyState is in use) |
| cleanup/album_merge_dialog, move_to_album_dialog, delete_files_dialogs | no | AlertDialog/Dialog, no house widgets |
| **devices/** devices_sheet | partial | Card, PeerCard |
| devices/peer_card | partial | Card |
| enrich_preview_dialog (root) | no | AlertDialog, centred CircularProgressIndicator, Colors. |
| track_edit_dialog (root) | no | full AppBar, AlertDialog |
| **history/** history_screen | partial | AppBar, CircularProgressIndicator loading (2.5 touched only the empty state) |
| **home/** and **now_playing/** | see packages | excluded from packages |
| **import/** import_banner | yes | none |
| import_intro_sheet, import_manual_search_sheet | partial/yes | intro: centred spinner; manual search clean |
| import_detail_screen | partial | AppBar, ChoiceChip (2.6 touched) |
| import_plan_screen | no | AppBar, RadioListTile, SegmentedButton-like choice |
| import_review_screen | partial | AppBar, ListTile |
| import_preview_dialog | no | AlertDialog, 3x RadioListTile |
| import_flow | no | Scaffold wrapper with plain structure |
| **jam/** jam_parts, jam_seek_bar | yes | none |
| jam_player_card | partial | Card |
| jam_outputs_sheet | partial | ChoiceChip x2 for single choice (use SegmentedBlocks) |
| jam_request_dialog | no | AlertDialog |
| jam_screen | partial | AppBar in 2 branches, centred loading, headlineSmall title (2.1/2.6 touched) |
| **library/** artist_screen, favorites_screen, album_detail_screen | partial/yes | artist and favorites yes; album_detail has an AlertDialog inside |
| library/library_shortcuts, library_toolbar | yes | none |
| library/all_tracks_screen | partial | SelectableAppBar / AppBar(), centred spinner (2.6/2.7 touched) |
| library/review_screen | partial | AppBar in non-active branch, ChoiceChip (2.6 touched) |
| library/second_opinion_log_screen | partial | plain AppBar |
| library/folders_sheet | no | ListTile stack, no CcSheet, no section header |
| library/scan_status | n/a | helper |
| **library/library_screen** | (table only) | excluded |
| **lyrics/** lyrics_screen | no | AppBar, Colors. x4, colorScheme |
| lyrics_view | partial | centred spinner |
| lyrics_translate_flow | no | AlertDialog, colorScheme |
| **memory/** memory_ring | yes | none |
| memory_screen | partial | ConstrainedBox, Colors.transparent, spinner (2.7 touched) |
| memory_app_data, memory_widgets | partial | spinner, Colors.transparent |
| never_played_screen | partial | SelectableAppBar, spinner |
| folder_labels | n/a | helper |
| **onboarding/** onboarding_pages, onboarding_screen, onboarding_gate | yes | none |
| **online/** artist_page_sections, artist_picker_sheet, catalog_error_view | yes/partial | catalog_error_view is hand-rolled |
| album_card, artist_card, artist_songs_screen (see below) | yes | album/artist cards clean |
| artist_page_screen | partial | AppBar(title: artist.name) |
| online_album_screen | partial | uses OnlinePageFrame |
| online_page_frame | no | SliverAppBar, surfaceTintColor Colors.transparent |
| discography_screen, artist_songs_screen | no | inherit the old OnlinePageFrame header |
| online_song_row | partial | Colors.transparent, spinner |
| **playlists/** playlist_detail_screen | partial | Colors.transparent, CollectionScaffold (2.1 touched) |
| playlist_picker | yes | none |
| add_tracks_screen | partial | plain AppBar |
| playlists_screen | partial | centred spinner, Colors.transparent |
| playlist_dialogs | partial | AlertDialog, ListTile x2 |
| export_dialog | no | AlertDialog, RadioListTile |
| **podcast/** podcast_subscribe_sheet | yes | none |
| podcast_detail_screen | partial | AppBar + CollectionHeader |
| podcasts_screen | partial | AppBar, spinner (2.6 touched) |
| podcast_texts | n/a | strings |
| **radio/** radio_station_row | yes | none |
| radio_sections | partial | ChoiceChip for genres, centred spinner (2.6 touched) |
| radio_region_sheet | partial | spinner x2, centred error text |
| radio_station_sheet | partial | AlertDialog |
| radio_screen | no | AppBar, FilterChip, no header |
| add_station_dialog | no | AlertDialog |
| radio_actions, radio_labels | n/a | helpers |
| **releases/** follow_button, top_artists_card | yes | none |
| followed_artists_screen | partial | AppBar, spinner |
| new_releases_screen | partial | AppBar line 92, ChoiceChip _chip (2.6 touched) |
| release_labels | n/a | helper |
| **search/** genre_screen | partial | AppBar in the empty branch, CollectionScaffold in the other |
| search_section_screen | partial | AppBar, EmptyState ok |
| search_screen | (table only) | excluded |
| **settings/** settings_pages | partial | SegmentedButton, 22 ListTile, desktop 760 constrained (2.5 touched) |
| settings_screen | partial | AppBar in the sub-page branch |
| theme_editor_screen | partial | AppBar, SegmentedButton x2 |
| theme_background_editor | no | SegmentedButton, colorScheme |
| equalizer_screen | no | AppBar, SegmentedButton, ChoiceChip, spinner |
| report_issue_screen | no | AppBar, SegmentedButton, colorScheme |
| missing_tracks_screen | partial | AppBar (EmptyState ok) |
| download_settings_tiles | no | RadioListTile |
| transition_settings_tiles | no | ChoiceChip |
| theme_tiles, release_settings_tiles, advanced_section, cleanup_tiles, icon_follow_tile, log_export_tile, shuffle_plus_tiles, tag_write_tiles, translation_models_tiles, trusted_devices_tiles, update_tiles | no | plain ListTile stacks, no section headers |
| backup_section, restore_dialog | no | AlertDialog, spinner |
| accent_picker | partial | Colors.transparent in swatch |
| theme_swatch | yes | none |
| theme_labels, settings_summaries, theme_labels, report_issue_tile | n/a | helpers |
| **share/** share_screen | partial | AppBar |
| track_picker_screen | no | AppBar, no house widgets |
| qr_scan_screen | no | AppBar |
| send_tab | no | RadioListTile, Card, colorScheme, Colors.white |
| receive_tab | no | colorScheme |
| pairing_dialogs | no | AlertDialog, colorScheme |
| incoming_offer_dialog, sync_preview_dialog | no | AlertDialog, ListTile |
| incoming_offer_tile | no | plain tile |
| sync_flow, offer_status_label | n/a | helpers |
| **smart/** smart_playlist_screen | yes | none |
| smart_playlist_editor | partial | AppBar |
| **stats/** stats_charts | yes | none |
| stats_screen | partial | AppBar (2.6 touched), centred spinner |
| **tags/** tags_sheet | partial | CcSheet ok, ListTile x7 |
| tags_screen | partial | AppBar + CollectionScaffold |
| **youtube/** listen_bar | partial | centred spinner x2 |
| online_results | partial | ChoiceChip via SourceFilterChips, Card x2 |
| online_results_sections | partial | ChoiceChip x4 (single-choice, should be SegmentedBlocks) |
| playlist_source_sheet | partial | centred spinners and Text in Center |
| **root** | | |

Work packages (disjoint, 8):
1. Settings screens: settings_pages, settings_screen, theme_editor_screen, theme_background_editor, equalizer_screen, report_issue_screen, missing_tracks_screen. Replace AppBar with CollectionScaffold/Header; SegmentedButton with SegmentedBlocks; EmptyState and ErrorState; drop colorScheme.
2. Settings tiles and small dialogs: download_settings_tiles, transition_settings_tiles, theme_tiles, release_settings_tiles, advanced_section, cleanup_tiles, icon_follow_tile, log_export_tile, shuffle_plus_tiles, tag_write_tiles, translation_models_tiles, trusted_devices_tiles, update_tiles, backup_section, restore_dialog, accent_picker. Add SectionHeader per group; ChoiceChip/RadioListTile to SegmentedBlocks; spinners to house loaders.
3. Share and devices: share_screen, send_tab, receive_tab, track_picker_screen, qr_scan_screen, pairing_dialogs, incoming_offer_dialog, incoming_offer_tile, sync_preview_dialog, devices_sheet, peer_card. Move dialogs to CcSheet, remove Card/colorScheme/Colors.white, use CollectionHeader.
4. Online, YouTube and Releases: online_page_frame (SliverAppBar, which also drives discography_screen and artist_songs_screen), artist_page_screen, online_album_screen, online_song_row, catalog_error_view; youtube online_results, online_results_sections (chips to SegmentedBlocks), listen_bar, playlist_source_sheet; releases followed_artists_screen, new_releases_screen.
5. Radio and Import: radio_screen (AppBar, FilterChip), radio_sections, radio_region_sheet, radio_station_sheet, add_station_dialog; import_plan_screen, import_preview_dialog (RadioListTile), import_review_screen, import_detail_screen, import_intro_sheet, import_flow.
6. Cleanup, Tags, Podcast, History, Activity: duplicates_screen (remove the 520 constraint on desktop, use wide layout), duplicate_group_card, duplicate_member_row, hidden_tracks_screen, tag_backups_screen, album_merge_dialog, move_to_album_dialog, delete_files_dialogs, tags_screen, tags_sheet, podcast_detail_screen, podcasts_screen, history_screen, activity_log_screen.
7. Jam, Lyrics, Car and root dialogs: jam_screen, jam_outputs_sheet, jam_player_card, jam_request_dialog, lyrics_screen (drop Colors., colorScheme), lyrics_view, lyrics_translate_flow, car_playlists_sheet (use CcSheet), enrich_preview_dialog, track_edit_dialog.
8. Stats, Memory, Library detail, Playlists, Smart: stats_screen, memory_screen, memory_app_data, memory_widgets, never_played_screen, all_tracks_screen, review_screen, second_opinion_log_screen, folders_sheet, album_detail_screen (dialog part), playlists/add_tracks_screen, playlists_screen, playlist_dialogs, export_dialog, smart_playlist_editor. Note that memory_screen and all_tracks_screen are in plan 2.6/2.7 and may be partly done.

Not checked: visual rendering, ALL-CAPS labels in ARBs, the plain-text empty states in the root dialogs, and the desktop layout beyond grep hits. Risk: the status column is inferred from counts; open the files before trusting a "partial" or "yes" call.
