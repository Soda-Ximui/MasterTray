PRIMITIVES = ["Jar", "Lid", "Tray", "Grid"];

echo(PRIMITIVES);

for (i = [0 : len(PRIMITIVES)-1]) {
   echo("PRIMITIVE: " + PRIMITIVES[i]);

}

PRIMITIVES = ["Jar", "Lid", "Tray", "Grid"];

for ( i = [ 0 : len(PRIMITIVES)]) {
    echo(str("PRIMITIVE ",PRIMITIVES[i]));
    }
