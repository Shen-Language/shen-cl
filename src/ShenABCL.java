// Based on code by Didier Verna found at
// https://www.didierverna.net/blog/index.php?post/2011/01/22/Towards-ABCL-Standalone-Executables

import java.util.stream.Stream;
import org.armedbear.lisp.*;

public class ShenABCL {
    public static void main(String[] args) {
        Runnable runShen = () -> {
            try {
                LispObject cmdline = Stream.of(args)
                    .reduce(Lisp.NIL.getSymbolValue(), (x, y) -> new Cons(y, x), (z, w) -> z)
                    .nreverse();
                Lisp._COMMAND_LINE_ARGUMENT_LIST_.setSymbolValue(cmdline);
                Interpreter.createInstance();
                Load.load(ShenABCL.class.getResourceAsStream("shen.abcl"));
            } catch (ProcessingTerminated e) {
                System.exit(e.getStatus());
            } catch (Exception e) {
                System.err.println("Uncaught Exception:");
                e.printStackTrace();
                System.exit(1);
            }
        };
        new Thread(null, runShen, "shen-abcl", 4194304L).start();
    }
}
