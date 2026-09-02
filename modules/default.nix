{
  myDeck    = import ./myDeck.nix;
  deck      = import ./deck.nix;
  installer = import ./installer.nix;
  disk      = import ./disk.nix;
}
