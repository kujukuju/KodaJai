
main :: () {
    thing: Thing(2, true);
    method(thing);
}

Thing :: struct (count: int, switch: bool) {

}

method :: (thing: Thing($count, true)) {
    
}

method :: (thing: Thing($count, false)) {
    
}
