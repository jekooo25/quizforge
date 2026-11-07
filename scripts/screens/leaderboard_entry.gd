extends HBoxContainer
func configure(row: Dictionary) -> void:
 %Rank.text="#%d" % int(row.rank)
 %Nickname.text=str(row.nickname)
 %Accuracy.text="%s%% · %d/%d correct" % [str(row.accuracy_percent),int(row.correct),int(row.answered)]
