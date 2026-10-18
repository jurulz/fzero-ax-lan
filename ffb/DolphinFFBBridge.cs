// SPDX-License-Identifier: GPL-2.0-or-later
// Copyright (c) 2026 F-Zero AX LAN contributors
// DolphinFFBBridge: force feedback bridge for F-Zero AX (Dolphin) -> vJoy / BackForceFeeder.
//
// Dolphin publishes, on 127.0.0.1:8000, the TARGET position the game wants the wheel to take (WheelServo).
// This program reads the real wheel position (axis of the vJoy device), computes a force
//    force = Kp * (target - position) - Kd * velocity
// and sends it to vJoy as a DirectInput "constant force" effect (through SDL2). BackForceFeeder receives
// that effect like for any other game and drives the motor.
//
// Build: csc /platform:x64 /out:DolphinFFBBridge.exe DolphinFFBBridge.cs
// Needs SDL2.dll (x64) next to the exe. Settings: ffb_bridge.ini (created on first run), reloaded on the fly.
// Interface (FFB_Settings.ahk): the bridge reads orders from ffb_cmd.txt (test / shock / enable / disable / toggle / quit)
// and writes its state to ffb_status.txt (key=value) every 200 ms.
using System;
using System.Globalization;
using System.IO;
using System.Net.Sockets;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;

namespace DolphinFFBBridge
{
    static class Sdl
    {
        const string Dll = "SDL2.dll";
        public const uint INIT_JOYSTICK = 0x00000200;
        public const uint INIT_HAPTIC = 0x00001000;
        public const ushort HAPTIC_CONSTANT = 1 << 0;
        public const ushort HAPTIC_GAIN = 1 << 12;
        public const ushort HAPTIC_AUTOCENTER = 1 << 13;
        public const uint HAPTIC_INFINITY = 4294967295U;

        [DllImport(Dll)] public static extern int SDL_Init(uint flags);
        [DllImport(Dll)] public static extern void SDL_Quit();
        [DllImport(Dll)] public static extern int SDL_SetHint([MarshalAs(UnmanagedType.LPStr)] string name, [MarshalAs(UnmanagedType.LPStr)] string value);
        [DllImport(Dll)] public static extern IntPtr SDL_GetError();
        [DllImport(Dll)] public static extern int SDL_NumJoysticks();
        [DllImport(Dll)] public static extern IntPtr SDL_JoystickNameForIndex(int index);
        [DllImport(Dll)] public static extern IntPtr SDL_JoystickOpen(int index);
        [DllImport(Dll)] public static extern void SDL_JoystickClose(IntPtr joystick);
        [DllImport(Dll)] public static extern int SDL_JoystickNumAxes(IntPtr joystick);
        [DllImport(Dll)] public static extern short SDL_JoystickGetAxis(IntPtr joystick, int axis);
        [DllImport(Dll)] public static extern void SDL_JoystickUpdate();
        [DllImport(Dll)] public static extern int SDL_JoystickIsHaptic(IntPtr joystick);
        [DllImport(Dll)] public static extern IntPtr SDL_HapticOpenFromJoystick(IntPtr joystick);
        [DllImport(Dll)] public static extern void SDL_HapticClose(IntPtr haptic);
        [DllImport(Dll)] public static extern uint SDL_HapticQuery(IntPtr haptic);
        [DllImport(Dll)] public static extern int SDL_HapticNewEffect(IntPtr haptic, IntPtr effect);
        [DllImport(Dll)] public static extern int SDL_HapticUpdateEffect(IntPtr haptic, int effect, IntPtr data);
        [DllImport(Dll)] public static extern int SDL_HapticRunEffect(IntPtr haptic, int effect, uint iterations);
        [DllImport(Dll)] public static extern int SDL_HapticStopEffect(IntPtr haptic, int effect);
        [DllImport(Dll)] public static extern void SDL_HapticDestroyEffect(IntPtr haptic, int effect);
        [DllImport(Dll)] public static extern int SDL_HapticStopAll(IntPtr haptic);
        [DllImport(Dll)] public static extern int SDL_HapticSetGain(IntPtr haptic, int gain);
        [DllImport(Dll)] public static extern int SDL_HapticSetAutocenter(IntPtr haptic, int autocenter);

        public static string Error()
        {
            return Marshal.PtrToStringAnsi(SDL_GetError());
        }
    }

    class Config
    {
        public int TcpPort = 8000;
        public string DeviceName = "vJoy";   // part of the device name
        public int DeviceIndex = -1;         // -1 = search by name
        public int Axis = 0;                 // 0 = X axis
        public double ServoScale = 50.0;     // WheelServo = +-ServoScale <=> wheel end stop (measured: the target never exceeds -50 / +51)
        public double Kp = 3.0;              // proportional gain (error of 1/Kp = maximum force)
        public double Kd = 0.12;             // damping (stability)
        public double MaxForce = 0.35;       // 0..1 : fraction of the maximum vJoy force
        public double SlewPerCycle = 0.08;   // maximum force change per 10 ms cycle
        public double Curve = 1.0;           // 0.2..1 : < 1 amplifies small forces (1 = linear)
        public double MinForce = 0.0;        // 0..0.5 : minimum force as soon as there is an order (overcomes friction)
        public bool InvertForce = false;     // reverses the force direction
        public bool InvertPosition = false;  // reverses the wheel axis direction
        public bool InitForce = false;       // also apply force during wheel initialization
        public bool StartEnabled = true;

        public static Config Load(string path)
        {
            Config c = new Config();
            if (!File.Exists(path))
            {
                File.WriteAllText(path, c.ToText(), Encoding.UTF8);
                return c;
            }
            foreach (string raw in File.ReadAllLines(path))
            {
                string line = raw.Trim();
                int hash = line.IndexOf('#');
                if (hash >= 0) line = line.Substring(0, hash).Trim();
                int eq = line.IndexOf('=');
                if (eq <= 0) continue;
                string key = line.Substring(0, eq).Trim().ToLowerInvariant();
                string val = line.Substring(eq + 1).Trim();
                double d;
                bool isNum = double.TryParse(val, NumberStyles.Float, CultureInfo.InvariantCulture, out d);
                switch (key)
                {
                    case "tcp_port": if (isNum) c.TcpPort = (int)d; break;
                    case "device_name": c.DeviceName = val; break;
                    case "device_index": if (isNum) c.DeviceIndex = (int)d; break;
                    case "axis": if (isNum) c.Axis = (int)d; break;
                    case "servo_scale": if (isNum && d > 1) c.ServoScale = d; break;
                    case "kp": if (isNum) c.Kp = d; break;
                    case "kd": if (isNum) c.Kd = d; break;
                    case "max_force": if (isNum) c.MaxForce = Math.Max(0, Math.Min(1, d)); break;
                    case "slew_per_cycle": if (isNum && d > 0) c.SlewPerCycle = d; break;
                    case "curve": if (isNum) c.Curve = Math.Max(0.2, Math.Min(1, d)); break;
                    case "min_force": if (isNum) c.MinForce = Math.Max(0, Math.Min(0.5, d)); break;
                    case "invert_force": c.InvertForce = val == "1"; break;
                    case "invert_position": c.InvertPosition = val == "1"; break;
                    case "init_force": c.InitForce = val == "1"; break;
                    case "start_enabled": c.StartEnabled = val != "0"; break;
                }
            }
            return c;
        }

        // Settings applied on the fly (device, axis and port need a restart).
        public void CopyTunablesFrom(Config o)
        {
            Axis = o.Axis; ServoScale = o.ServoScale; Kp = o.Kp; Kd = o.Kd; MaxForce = o.MaxForce;
            SlewPerCycle = o.SlewPerCycle; Curve = o.Curve; MinForce = o.MinForce; InvertForce = o.InvertForce; InvertPosition = o.InvertPosition;
            InitForce = o.InitForce;
        }

        public string ToText()
        {
            StringBuilder sb = new StringBuilder();
            sb.AppendLine("# Force feedback bridge settings (F-Zero AX / Dolphin -> vJoy). Decimal point notation.");
            sb.AppendLine("tcp_port = 8000            # Dolphin outputs port");
            sb.AppendLine("device_name = vJoy         # part of the device name (list: DolphinFFBBridge.exe --list)");
            sb.AppendLine("device_index = -1          # or exact device number (-1 = use device_name)");
            sb.AppendLine("axis = 0                   # wheel axis: 0 = X, 1 = Y, 2 = Z ...");
            sb.AppendLine("servo_scale = 50           # WheelServo value matching the wheel end stop (measured: -50 to +51)");
            sb.AppendLine("kp = 3.0                  # gain: higher = the wheel is pulled harder toward the target");
            sb.AppendLine("kd = 0.12                 # damping: higher = fewer oscillations");
            sb.AppendLine("max_force = 0.35          # 0 to 1: force CEILING. Start low (0.2) then increase.");
            sb.AppendLine("slew_per_cycle = 0.08      # max force change every 10 ms (smooths jolts)");
            sb.AppendLine("curve = 1.0                # 0.2 to 1: lower = small forces are amplified (1 = linear)");
            sb.AppendLine("min_force = 0.0            # 0 to 0.5: minimum force as soon as there is an order (overcomes motor friction)");
            sb.AppendLine("invert_force = 0           # set to 1 if the wheel is pushed the wrong way (see --test)");
            sb.AppendLine("invert_position = 0        # set to 1 if the wheel axis is reversed");
            sb.AppendLine("init_force = 0             # 1 = also during 'Motor Initializing' (the wheel sweeps its whole travel)");
            sb.AppendLine("start_enabled = 1          # 0 = start with the force cut (Space to enable it)");
            return sb.ToString();
        }
    }

    // State published by Dolphin (filled by the network thread).
    class DolphinState
    {
        readonly object sync = new object();
        bool connected;
        int servo, wheelInit, power, mameRun;
        public void Reset() { lock (sync) { servo = 0; wheelInit = 0; power = 0; mameRun = 0; } }
        public void SetConnected(bool v) { lock (sync) { connected = v; } }
        public void Snapshot(out bool conn, out int sv, out int init, out int pw, out int run)
        {
            lock (sync) { conn = connected; sv = servo; init = wheelInit; pw = power; run = mameRun; }
        }
        public void Apply(string name, int value)
        {
            lock (sync)
            {
                switch (name)
                {
                    case "WheelServo": servo = value; break;
                    case "WheelInit": wheelInit = value; break;
                    case "WheelCmd0": power = value; break;
                    case "mamerun": mameRun = value; break;
                }
            }
        }
    }

    class Program
    {
        static volatile bool quit;

        static void NetworkLoop(int port, DolphinState state, bool verbose)
        {
            while (!quit)
            {
                try
                {
                    using (TcpClient client = new TcpClient())
                    {
                        client.Connect("127.0.0.1", port);
                        state.Reset();
                        state.SetConnected(true);
                        StreamReader reader = new StreamReader(client.GetStream(), Encoding.ASCII);
                        string line;
                        while ((line = reader.ReadLine()) != null)
                        {
                            int eq = line.IndexOf('=');
                            if (eq <= 0) continue;
                            string name = line.Substring(0, eq).Trim();
                            int value;
                            if (int.TryParse(line.Substring(eq + 1).Trim(), NumberStyles.Integer, CultureInfo.InvariantCulture, out value))
                                state.Apply(name, value);
                        }
                    }
                }
                catch (Exception)
                {
                    // Dolphin not (yet) running: try again
                }
                state.SetConnected(false);
                state.Reset();
                if (!quit) Thread.Sleep(1000);
            }
        }

        static string statusPath;

        // Writes the state for the interface (temporary file then copy: never a half-read file)
        static void WriteStatus(string text)
        {
            try
            {
                string tmp = statusPath + ".tmp";
                File.WriteAllText(tmp, text, Encoding.ASCII);
                File.Copy(tmp, statusPath, true);
            }
            catch (Exception) { }
        }

        // Fatal error: message in the console AND in the status file (the interface shows it)
        static int Fatal(string msg, int code)
        {
            Console.WriteLine(msg);
            WriteStatus("alive=0\nerror=" + msg.Replace('\n', ' ') + "\n");
            return code;
        }

        // Reads then deletes the interface's orders file
        static string TakeCommands(string cmdPath)
        {
            try
            {
                if (!File.Exists(cmdPath)) return null;
                string run = cmdPath + ".run";
                if (File.Exists(run)) File.Delete(run);
                File.Move(cmdPath, run);
                string txt = File.ReadAllText(run);
                File.Delete(run);
                return txt;
            }
            catch (Exception) { return null; }
        }

        static bool KeyAvailableSafe()
        {
            try { return Console.KeyAvailable; } catch (Exception) { return false; }
        }

        static int ConsoleWidthSafe()
        {
            try { return Console.WindowWidth > 1 ? Console.WindowWidth - 1 : 110; } catch (Exception) { return 110; }
        }

        static void ListDevices()
        {
            Sdl.SDL_SetHint("SDL_JOYSTICK_ALLOW_BACKGROUND_EVENTS", "1");
            Sdl.SDL_SetHint("SDL_JOYSTICK_RAWINPUT", "0");
            Sdl.SDL_SetHint("SDL_JOYSTICK_HIDAPI", "0");
            Sdl.SDL_SetHint("SDL_XINPUT_ENABLED", "0");
            if (Sdl.SDL_Init(Sdl.INIT_JOYSTICK | Sdl.INIT_HAPTIC) != 0)
            {
                Console.WriteLine("SDL_Init failed: " + Sdl.Error());
                return;
            }
            int n = Sdl.SDL_NumJoysticks();
            Console.WriteLine("Game devices detected: " + n);
            for (int i = 0; i < n; i++)
            {
                string name = Marshal.PtrToStringAnsi(Sdl.SDL_JoystickNameForIndex(i));
                IntPtr joy = Sdl.SDL_JoystickOpen(i);
                string info = "(cannot be opened)";
                if (joy != IntPtr.Zero)
                {
                    info = "axes=" + Sdl.SDL_JoystickNumAxes(joy) + "  force feedback=" + (Sdl.SDL_JoystickIsHaptic(joy) > 0 ? "YES" : "no");
                    Sdl.SDL_JoystickClose(joy);
                }
                Console.WriteLine("  [" + i + "] " + name + "   " + info);
            }
            Sdl.SDL_Quit();
        }

        static IntPtr NewConstantEffect(short level, int mode)
        {
            // SDL_HapticConstant (40 bytes) in a 128-byte buffer (size >= SDL_HapticEffect)
            IntPtr p = Marshal.AllocHGlobal(128);
            for (int i = 0; i < 128; i += 4) Marshal.WriteInt32(p, i, 0);
            Marshal.WriteInt16(p, 0, (short)Sdl.HAPTIC_CONSTANT);   // type
            Marshal.WriteByte(p, 4, 1);                             // direction.type = SDL_HAPTIC_CARTESIAN
            Marshal.WriteInt32(p, 8, 1);                            // direction.dir[0] = 1 (X axis)
            Marshal.WriteInt32(p, 20, unchecked((int)Sdl.HAPTIC_INFINITY)); // length
            Marshal.WriteInt16(p, 30, level);                       // level
            return p;
        }

        static void SetLevel(IntPtr effect, short level)
        {
            Marshal.WriteInt16(effect, 30, level);
        }

        static int Main(string[] args)
        {
            bool dry = false, test = false, keepAlive = false;
            foreach (string a in args)
            {
                if (a == "--list") { ListDevices(); return 0; }
                if (a == "--dry") dry = true;
                if (a == "--test") test = true;
                if (a == "--keep") keepAlive = true;   // simulation without the 60 s limit (used by the interface)
            }

            string baseDir = AppDomain.CurrentDomain.BaseDirectory;
            string iniPath = Path.Combine(baseDir, "ffb_bridge.ini");
            string cmdPath = Path.Combine(baseDir, "ffb_cmd.txt");
            statusPath = Path.Combine(baseDir, "ffb_status.txt");
            try { File.Delete(cmdPath); } catch (Exception) { }
            Config cfg = Config.Load(iniPath);

            Console.WriteLine("=== F-Zero AX force feedback bridge (Dolphin) -> vJoy ===");
            Console.WriteLine("Settings: " + iniPath + "  (reloaded on the fly)");
            Console.WriteLine("Keys: [Space] cut/restore force   [+] [-] max force   [I] invert force   [T] test   [Q] quit");

            IntPtr joy = IntPtr.Zero, haptic = IntPtr.Zero, effect = IntPtr.Zero;
            int effectId = -1;

            if (!dry)
            {
                Sdl.SDL_SetHint("SDL_JOYSTICK_ALLOW_BACKGROUND_EVENTS", "1");
                Sdl.SDL_SetHint("SDL_JOYSTICK_RAWINPUT", "0");
                Sdl.SDL_SetHint("SDL_JOYSTICK_HIDAPI", "0");
                Sdl.SDL_SetHint("SDL_XINPUT_ENABLED", "0");
                if (Sdl.SDL_Init(Sdl.INIT_JOYSTICK | Sdl.INIT_HAPTIC) != 0)
                {
                    return Fatal("ERROR SDL_Init: " + Sdl.Error(), 1);
                }
                int count = Sdl.SDL_NumJoysticks();
                int chosen = cfg.DeviceIndex;
                if (chosen < 0)
                {
                    for (int i = 0; i < count; i++)
                    {
                        string name = Marshal.PtrToStringAnsi(Sdl.SDL_JoystickNameForIndex(i)) ?? "";
                        if (name.IndexOf(cfg.DeviceName, StringComparison.OrdinalIgnoreCase) >= 0) { chosen = i; break; }
                    }
                }
                if (chosen < 0 || chosen >= count)
                {
                    return Fatal("ERROR: no device containing '" + cfg.DeviceName + "' (see --list). " + count + " device(s) seen.", 2);
                }
                joy = Sdl.SDL_JoystickOpen(chosen);
                if (joy == IntPtr.Zero) return Fatal("ERROR opening the device: " + Sdl.Error(), 3);
                Console.WriteLine("Wheel: [" + chosen + "] " + Marshal.PtrToStringAnsi(Sdl.SDL_JoystickNameForIndex(chosen)) + "  (axis " + cfg.Axis + ")");
                if (Sdl.SDL_JoystickIsHaptic(joy) <= 0)
                {
                    return Fatal("ERROR: this device does not report force feedback (enable FFB in vJoy / BackForceFeeder).", 4);
                }
                haptic = Sdl.SDL_HapticOpenFromJoystick(joy);
                if (haptic == IntPtr.Zero) return Fatal("ERROR force feedback: " + Sdl.Error(), 5);
                uint caps = Sdl.SDL_HapticQuery(haptic);
                if ((caps & Sdl.HAPTIC_CONSTANT) == 0)
                {
                    return Fatal("ERROR: the 'constant force' effect is not available on this device.", 6);
                }
                if ((caps & Sdl.HAPTIC_GAIN) != 0) Sdl.SDL_HapticSetGain(haptic, 100);
                if ((caps & Sdl.HAPTIC_AUTOCENTER) != 0) Sdl.SDL_HapticSetAutocenter(haptic, 0);
                effect = NewConstantEffect(0, 0);
                effectId = Sdl.SDL_HapticNewEffect(haptic, effect);
                if (effectId < 0) return Fatal("ERROR creating the effect: " + Sdl.Error(), 7);
                if (Sdl.SDL_HapticRunEffect(haptic, effectId, Sdl.HAPTIC_INFINITY) != 0)
                {
                    return Fatal("ERROR starting the effect: " + Sdl.Error(), 8);
                }
            }
            else
            {
                Console.WriteLine("SIMULATION MODE (--dry): no device used, the wheel is simulated.");
            }

            DolphinState state = new DolphinState();
            Thread net = new Thread(delegate () { NetworkLoop(cfg.TcpPort, state, false); });
            net.IsBackground = true;
            net.Start();

            Console.CancelKeyPress += delegate (object s, ConsoleCancelEventArgs e) { e.Cancel = true; quit = true; };

            bool enabled = cfg.StartEnabled;
            bool invert = cfg.InvertForce;
            double maxForce = cfg.MaxForce;
            double pos = 0, lastPos = 0, velF = 0, force = 0, simPos = 0;
            short lastLevel = 0;
            DateTime lastStatus = DateTime.MinValue;
            DateTime lastUpdate = DateTime.MinValue;
            DateTime testUntil = DateTime.MinValue;
            DateTime shockUntil = DateTime.MinValue;
            double peak = 0;
            DateTime lastPoll = DateTime.MinValue;
            DateTime lastStatusFile = DateTime.MinValue;
            DateTime iniStamp = DateTime.MinValue;
            try { iniStamp = File.GetLastWriteTimeUtc(iniPath); } catch (Exception) { }
            int stateCode = 0;
            double testForce = 0;
            DateTime start = DateTime.UtcNow;
            const double dt = 0.01;
            int errors = 0;

            if (test) { testUntil = DateTime.UtcNow.AddSeconds(2.4); }

            try
            {
                while (!quit)
                {
                    while (KeyAvailableSafe())
                    {
                        ConsoleKeyInfo k = Console.ReadKey(true);
                        if (k.Key == ConsoleKey.Q) quit = true;
                        else if (k.Key == ConsoleKey.Spacebar) enabled = !enabled;
                        else if (k.KeyChar == '+') maxForce = Math.Min(1.0, maxForce + 0.05);
                        else if (k.KeyChar == '-') maxForce = Math.Max(0.0, maxForce - 0.05);
                        else if (k.Key == ConsoleKey.I) invert = !invert;
                        else if (k.Key == ConsoleKey.T) testUntil = DateTime.UtcNow.AddSeconds(2.4);
                    }

                    if ((DateTime.UtcNow - lastPoll).TotalMilliseconds >= 250)
                    {
                        lastPoll = DateTime.UtcNow;
                        try
                        {
                            DateTime stamp = File.GetLastWriteTimeUtc(iniPath);
                            if (stamp != iniStamp)
                            {
                                Config fresh = Config.Load(iniPath);
                                cfg.CopyTunablesFrom(fresh);
                                maxForce = cfg.MaxForce;
                                invert = cfg.InvertForce;
                                iniStamp = stamp;
                            }
                        }
                        catch (Exception) { }
                        string orders = TakeCommands(cmdPath);
                        if (orders != null)
                        {
                            foreach (string o in orders.Split('\n'))
                            {
                                string c = o.Trim().ToLowerInvariant();
                                if (c == "test") testUntil = DateTime.UtcNow.AddSeconds(2.4);
                                else if (c == "shock") shockUntil = DateTime.UtcNow.AddSeconds(0.9);
                                else if (c == "enable") enabled = true;
                                else if (c == "disable") enabled = false;
                                else if (c == "toggle") enabled = !enabled;
                                else if (c == "quit") quit = true;
                            }
                        }
                    }

                    // real wheel position (-1..+1)
                    if (!dry)
                    {
                        Sdl.SDL_JoystickUpdate();
                        pos = Sdl.SDL_JoystickGetAxis(joy, cfg.Axis) / 32767.0;
                    }
                    else
                    {
                        pos = simPos;
                    }
                    if (pos > 1) pos = 1; if (pos < -1) pos = -1;
                    if (cfg.InvertPosition) pos = -pos;

                    bool conn; int servo, init, power, run;
                    state.Snapshot(out conn, out servo, out init, out power, out run);

                    double desired = 0;
                    bool active = false;
                    bool shockNow = DateTime.UtcNow < shockUntil;
                    if (shockNow)
                    {
                        // shock: maximum force to the right (0.25 s), pause, maximum force to the left (0.25 s)
                        double t = 0.9 - (shockUntil - DateTime.UtcNow).TotalSeconds;
                        desired = (t < 0.25 ? 1.0 : (t >= 0.45 && t < 0.70 ? -1.0 : 0.0)) * maxForce;
                        active = true;
                    }
                    else if (DateTime.UtcNow < testUntil)
                    {
                        // test: gentle push to the right (0.0-0.8 s), then to the left (0.8-1.6 s)
                        double t = 2.4 - (testUntil - DateTime.UtcNow).TotalSeconds;
                        testForce = t < 0.8 ? 0.4 : (t < 1.6 ? -0.4 : 0.0);
                        desired = testForce * maxForce;
                        active = true;
                    }
                    else if (enabled && conn && run == 1 && power == 1 && (init == 2 || (cfg.InitForce && init != 0)))
                    {
                        double target = servo / cfg.ServoScale;
                        if (target > 1) target = 1; if (target < -1) target = -1;
                        double vel = (pos - lastPos) / dt;
                        velF = 0.8 * velF + 0.2 * vel;
                        double f = cfg.Kp * (target - pos) - cfg.Kd * velF;
                        if (f > 1) f = 1; if (f < -1) f = -1;
                        double a = Math.Abs(f);
                        if (a < 0.02) a = 0;
                        else a = cfg.MinForce + (1 - cfg.MinForce) * Math.Pow(a, cfg.Curve);
                        desired = (f < 0 ? -a : a) * maxForce;
                        active = true;
                    }
                    lastPos = pos;

                    // smoothing: maximum change per cycle
                    double delta = desired - force;
                    if (!shockNow)
                    {
                        if (delta > cfg.SlewPerCycle) delta = cfg.SlewPerCycle;
                        if (delta < -cfg.SlewPerCycle) delta = -cfg.SlewPerCycle;
                    }
                    force += delta;
                    peak = Math.Max(Math.Abs(force), peak * 0.995);
                    if (!active && Math.Abs(force) < 0.001) force = 0;

                    double sign = invert ? -1.0 : 1.0;
                    short level = (short)Math.Round(Math.Max(-1.0, Math.Min(1.0, force * sign)) * 32767.0);
                    if (!dry)
                    {
                        if (level != lastLevel || (DateTime.UtcNow - lastUpdate).TotalMilliseconds > 250)
                        {
                            SetLevel(effect, level);
                            if (Sdl.SDL_HapticUpdateEffect(haptic, effectId, effect) != 0)
                            {
                                if (++errors % 50 == 1) Console.WriteLine("\n[!] force update: " + Sdl.Error());
                            }
                            lastLevel = level;
                            lastUpdate = DateTime.UtcNow;
                        }
                    }
                    else
                    {
                        // simulated wheel: follows the force with inertia and a restoring pull
                        simPos += (force * sign * 1.5 - simPos * 0.2) * dt;
                        if (simPos > 1) simPos = 1; if (simPos < -1) simPos = -1;
                        lastLevel = level;
                    }

                    if ((DateTime.UtcNow - lastStatus).TotalMilliseconds >= 500)
                    {
                        lastStatus = DateTime.UtcNow;
                        string stateText = !conn ? "Dolphin: not connected" :
                            (run != 1 ? "Dolphin: game stopped" :
                            (init != 2 ? "wheel: initializing (force off)" :
                            (power != 1 ? "motor: off by the game" : (enabled ? "FORCE ACTIVE" : "force CUT (Space)"))));
                        string line = string.Format(CultureInfo.InvariantCulture,
                            "{0,-40} target={1,4}  pos={2,6:0.00}  force={3,6:0.00}  max={4:0.00}{5}",
                            stateText, servo, pos, force * sign, maxForce, invert ? "  [inverted]" : "");
                        Console.Write("\r" + line.PadRight(ConsoleWidthSafe()));
                    }

                    stateCode = (DateTime.UtcNow < testUntil || shockNow) ? 6 :
                        (!conn ? 0 : (run != 1 ? 1 : (init != 2 ? 2 : (power != 1 ? 3 : (enabled ? 4 : 5)))));
                    if ((DateTime.UtcNow - lastStatusFile).TotalMilliseconds >= 200)
                    {
                        lastStatusFile = DateTime.UtcNow;
                        WriteStatus(string.Format(CultureInfo.InvariantCulture,
                            "alive=1\nstate={0}\nservo={1}\npos={2:0.000}\nforce={3:0.000}\nmax={4:0.000}\nenabled={5}\ninvert={6}\ndry={7}\npeak={8:0.000}\n",
                            stateCode, servo, pos, force * sign, maxForce, enabled ? 1 : 0, invert ? 1 : 0, dry ? 1 : 0, peak));
                    }

                    if (dry && !keepAlive && (DateTime.UtcNow - start).TotalSeconds > 60) quit = true;
                    Thread.Sleep(10);
                }
            }
            finally
            {
                Console.WriteLine("\nStopped: force reset to zero.");
                WriteStatus("alive=0\n");
                if (!dry && haptic != IntPtr.Zero)
                {
                    try
                    {
                        SetLevel(effect, 0);
                        Sdl.SDL_HapticUpdateEffect(haptic, effectId, effect);
                        Sdl.SDL_HapticStopAll(haptic);
                        Sdl.SDL_HapticDestroyEffect(haptic, effectId);
                        Sdl.SDL_HapticClose(haptic);
                        Sdl.SDL_JoystickClose(joy);
                    }
                    catch (Exception) { }
                    Sdl.SDL_Quit();
                }
            }
            return 0;
        }
    }
}
