@filename = ask_open_file
Shoes.app do
  background "#DFA"
  @exec_seq = stack do
    para "Execution Sequence"
    para File.read(@filename)
  end
end
