extends Node2D

const ScoreItem = preload("ScoreItem.tscn")
const SWLogger = preload("res://silent_wolf/utils/SWLogger.gd")

var list_index = 0
@export var ld_name = "main"
var max_scores = 10
@export var show_player_name := true

var _pending_request_id := 0
var _request_seq := 0

func _ready():
    load_leaderboard(ld_name)


func load_leaderboard(new_ld_name: String) -> void:
    ld_name = new_ld_name
    clear_leaderboard()
    list_index = 0
    hide_message()

    var silentwolf := _get_silentwolf()
    if silentwolf == null:
        add_no_scores_message()
        return

    var scores_api = silentwolf.Scores

    var scores: Array = []
    if ld_name in scores_api.leaderboards:
        scores = scores_api.leaderboards[ld_name]
    var local_scores = scores_api.local_scores

    if scores.size() > 0:
        render_board(scores, local_scores)
        return

    add_loading_scores_message()
    _request_seq += 1
    var request_id := _request_seq
    _pending_request_id = request_id

    if scores_api.sw_get_scores_complete.is_connected(_on_get_scores_complete):
        scores_api.sw_get_scores_complete.disconnect(_on_get_scores_complete)
    scores_api.sw_get_scores_complete.connect(_on_get_scores_complete.bind(request_id, ld_name), CONNECT_ONE_SHOT)

    scores_api.get_scores(max_scores, ld_name)
    _start_load_timeout(request_id, ld_name)


func _start_load_timeout(request_id: int, expected_ld_name: String) -> void:
    var timer := get_tree().create_timer(4.0)
    timer.timeout.connect(func() -> void:
        if _pending_request_id != request_id:
            return
        if ld_name != expected_ld_name:
            return
        _pending_request_id = 0
        var item = $"Board/MessageContainer/TextMessage"
        item.text = "Unable to load scores."
        $"Board/MessageContainer".show()
        item.offset_top = 135
    , CONNECT_ONE_SHOT)


func _on_get_scores_complete(sw_result: Dictionary, request_id: int, expected_ld_name: String) -> void:
    if _pending_request_id != request_id:
        return
    if ld_name != expected_ld_name:
        return
    _pending_request_id = 0

    hide_message()
    var scores: Array = sw_result.get("scores", [])
    var silentwolf := _get_silentwolf()
    var local_scores: Array = []
    if silentwolf != null:
        local_scores = silentwolf.Scores.local_scores
    render_board(scores, local_scores)


func render_board(scores: Array, local_scores: Array) -> void:
    var all_scores = scores
    if all_scores.is_empty():
        add_no_scores_message()
    else:
        for score in all_scores:
            add_item(score.player_name, str(int(score.score)))


func is_default_leaderboard(ld_config: Dictionary) -> bool:
    var default_insert_opt = (ld_config.insert_opt == "keep")
    var not_time_based = !("time_based" in ld_config)
    return default_insert_opt and not_time_based


func merge_scores_with_local_scores(scores: Array, local_scores: Array, max_scores: int=10) -> Array:
    if local_scores:
        for score in local_scores:
            var in_array = score_in_score_array(scores, score)
            if !in_array:
                scores.append(score)
            scores.sort_custom(sort_by_score);
    if scores.size() > max_scores:
        var new_size = scores.resize(max_scores)
    return scores


func sort_by_score(a: Dictionary, b: Dictionary) -> bool:
    return a.score > b.score


func score_in_score_array(scores: Array, new_score: Dictionary) -> bool:
    var in_score_array =  false
    if !new_score.is_empty() and !scores.is_empty():
        for score in scores:
            if score.score_id == new_score.score_id: # score.player_name == new_score.player_name and score.score == new_score.score:
                in_score_array = true
    return in_score_array


func add_item(player_name: String, score_value: String) -> void:
    var item = ScoreItem.instantiate()
    list_index += 1
    if show_player_name:
        item.get_node("PlayerName").text = str(list_index) + str(". ") + player_name
    else:
        item.get_node("PlayerName").visible = false
    item.get_node("Score").text = score_value
    
    $"Board/HighScores/ScoreItemContainer".add_child(item)


func add_no_scores_message() -> void:
    var item = $"Board/MessageContainer/TextMessage"
    item.text = "No scores yet!"
    $"Board/MessageContainer".show()
    item.offset_top = 135


func add_loading_scores_message() -> void:
    var item = $"Board/MessageContainer/TextMessage"
    item.text = "Loading scores..."
    $"Board/MessageContainer".show()
    item.offset_top = 135


func hide_message() -> void:
    $"Board/MessageContainer".hide()


func clear_leaderboard() -> void:
    var score_item_container = $"Board/HighScores/ScoreItemContainer"
    if score_item_container.get_child_count() > 0:
        var children = score_item_container.get_children()
        for c in children:
            score_item_container.remove_child(c)
            c.queue_free()


func _on_CloseButton_pressed() -> void:
    SFXManager.play_sfx(preload("res://Audio/SFX/MenuSFX/Unequip.wav"))
    var silentwolf := _get_silentwolf()
    if silentwolf == null:
        get_tree().change_scene_to_file("res://main_menu.tscn")
        return
    var scene_name = silentwolf.scores_config.open_scene_on_close
    SWLogger.info("Closing SilentWolf leaderboard, switching to scene: " + str(scene_name))
    get_tree().change_scene_to_file(scene_name)


func _get_silentwolf() -> Node:
    var tree := get_tree()
    if tree == null:
        return null
    return tree.root.get_node_or_null("SilentWolf")
