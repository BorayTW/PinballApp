class_name UpdateManager
extends Node

# ==========================================
# 🔄 在線版本檢查與更新管理器 (UpdateManager.gd)
# ==========================================

# 💡 請填入你的 GitHub 帳號與倉庫名稱
@export var github_username: String = "BorayTW" # 替換為你的 GitHub 帳號
@export var github_repo: String = "PinballApp"     # 替換為你的 Repository 名稱

var http_request: HTTPRequest
var download_request: HTTPRequest

var latest_version_tag: String = ""
var apk_download_url: String = ""
var target_apk_path: String = "user://update.apk"

func _ready() -> void:
	http_request = HTTPRequest.new()
	download_request = HTTPRequest.new()
	add_child(http_request)
	add_child(download_request)
	
	http_request.request_completed.connect(_on_version_check_completed)
	download_request.request_completed.connect(_on_apk_download_completed)

## 向 GitHub API 發送請求查詢最新 Release
func check_for_updates() -> void:
	if github_username == "YourUsername" or github_repo == "YourRepoName":
		print("未設定 GitHub 帳號與專案庫名稱，跳過更新檢查")
		return

	var api_url = "https://api.github.com/repos/%s/%s/releases/latest" % [github_username, github_repo]
	var headers = ["User-Agent: Godot-App-Updater"]
	http_request.request(api_url, headers)

## 解析 GitHub API 回傳的 Release 資訊
func _on_version_check_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		print("版本檢查失敗，HTTP 狀態碼:", response_code)
		return

	var json = JSON.new()
	if json.parse(body.get_string_from_utf8()) != OK: return

	var data = json.get_data()
	if not data is Dictionary: return

	# 抓取雲端 Release Tag (例如 "v0.1.2")[cite: 1]
	latest_version_tag = data.get("tag_name", "")
	var clean_cloud_ver = latest_version_tag.replace("v", "").replace("V", "").strip_edges()
	
	# 抓取本地 project.godot 設定的版本號 (例如 "0.1.1")[cite: 1, 2]
	var local_ver = ProjectSettings.get_setting("application/config/version", "1.0.0").strip_edges()

	# 比對版本[cite: 1]
	if _is_version_newer(clean_cloud_ver, local_ver):
		var assets = data.get("assets", [])
		for asset in assets:
			var download_url = asset.get("browser_download_url", "")
			if download_url.ends_with(".apk"):
				apk_download_url = download_url
				break
		
		if apk_download_url != "":
			_show_update_dialog(clean_cloud_ver)

## 比對版本號數字[cite: 1]
func _is_version_newer(cloud_ver: String, local_ver: String) -> bool:
	var cloud_parts = cloud_ver.split(".")
	var local_parts = local_ver.split(".")
	var max_len = max(cloud_parts.size(), local_parts.size())
	
	for i in range(max_len):
		var c_num = cloud_parts[i].to_int() if i < cloud_parts.size() else 0
		var l_num = local_parts[i].to_int() if i < local_parts.size() else 0
		if c_num > l_num: return true
		if c_num < l_num: return false
	return false

## 彈出更新提示 UI[cite: 1]
func _show_update_dialog(new_ver: String) -> void:
	var main_node = get_tree().current_scene
	var ui_layer = main_node.get_node_or_null("UI")
	if not ui_layer: return

	var panel = PanelContainer.new()
	panel.name = "UpdatePanel"
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(340, 180)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 15)
	
	var title = Label.new()
	title.text = "🎉 發現新版本 v" + new_ver
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	
	var msg = Label.new()
	msg.text = "檢測到更新，是否下載更新檔？"
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	var hbox = HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 20)
	
	var update_btn = Button.new()
	update_btn.text = "下載更新"
	update_btn.custom_minimum_size = Vector2(110, 40)
	update_btn.pressed.connect(func(): _start_apk_download(msg, update_btn))
	
	var cancel_btn = Button.new()
	cancel_btn.text = "稍後再說"
	cancel_btn.custom_minimum_size = Vector2(110, 40)
	cancel_btn.pressed.connect(func(): panel.queue_free())
	
	hbox.add_child(update_btn)
	hbox.add_child(cancel_btn)
	vbox.add_child(title)
	vbox.add_child(msg)
	vbox.add_child(hbox)
	panel.add_child(vbox)
	ui_layer.add_child(panel)

## 下載 APK[cite: 1]
func _start_apk_download(status_label: Label, update_btn: Button) -> void:
	update_btn.disabled = true
	status_label.text = "正在下載更新檔，請稍候..."
	
	download_request.download_file = target_apk_path
	var err = download_request.request(apk_download_url)
	if err != OK:
		status_label.text = "下載失敗，請檢查網路連線。"
		update_btn.disabled = false

## 下載完成並調起 Android 安裝畫面[cite: 1]
func _on_apk_download_completed(result: int, response_code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	if result == HTTPRequest.RESULT_SUCCESS and response_code == 200:
		var global_apk_path = ProjectSettings.globalize_path(target_apk_path)
		OS.shell_open(global_apk_path) # 觸發 Android 原生覆蓋安裝[cite: 1]
	else:
		print("APK 下載失敗")
