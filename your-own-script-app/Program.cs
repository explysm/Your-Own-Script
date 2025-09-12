using System;

class Program {
    static void Main() {
        string answer = "";
        string name = "";
        Console.WriteLine("hi! What is your name?");
        name = Console.ReadLine();
        Console.WriteLine("Haha... "+name+" nice name...!");
        Console.WriteLine("Would you like to play a game with me?");
        answer = Console.ReadLine();
        if ((answer == "yes"))
        {
            Console.WriteLine("Great!");
        }
        if ((answer == "no"))
        {
            Console.WriteLine(":(");
        }
    }
}
