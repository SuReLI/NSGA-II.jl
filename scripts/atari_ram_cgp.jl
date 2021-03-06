using CartesianGeneticProgramming
using Cambrian
using ArcadeLearningEnvironment
using ArgParse
using NSGAII

import Cambrian.mutate
import Random

```
Playing Atari games using classic CGP on RAM values
If an individual is provided using --ind, an evaluation loop with rendering will
be performed. Otherwise, an evolution is launched. By default this uses seed=0
for each evaluation for a deterministic environment, but this can be removed for
a stochastic and more realistic result.
```

s = ArgParseSettings()
@add_arg_table s begin
    "--cfg"
    help = "configuration script"
    default = "./cfg/atari_ram.yaml"
    "--game"
    help = "game rom name"
    arg_type = Array{String}
    default = ["centipede","frostbite","ms_pacman"]
    "--seed"
    help = "random seed for evolution"
    arg_type = Int
    default = 0
    "--ind"
    help = "individual for evaluation"
    arg_type = String
    default = ""
end
args = parse_args(ARGS, s)

function play_atari(ind::CGPInd, rom_name::Array{String}; seed=0, max_frames=18000, render=false)
    rewards=[]
    ale = ALE_new()
    setInt(ale, "random_seed", Cint(seed))
    if render
        setBool(ale, "display_screen", true)
        setBool(ale, "sound", true)
    end
    for i in 1:length(rom_name)
        loadROM(ale, rom_name[i])
        actions = getMinimalActionSet(ale)
        reward = 0.0
        frames = 0
        while ~game_over(ale)
            ram = getRAM(ale) ./ typemax(UInt8)
            output = argmax(process(ind, ram))
            if rom_name[i]=="ms_pacman"
                output=output%9 + 1
            end
            action = actions[output]
            reward += act(ale, action)
            frames += 1
            if frames > max_frames
                break
            end
        end
        push!(rewards,reward)
    end
    ALE_del(ale)
    rewards
end

ale = ALE_new()
loadROM(ale, args["game"][1])
n_in = length(getRAM(ale))
n_out = length(getMinimalActionSet(ale))
ALE_del(ale)

cfg = get_config(args["cfg"]; game=args["game"], n_in=n_in, n_out=n_out)
Random.seed!(args["seed"])

if length(args["ind"]) > 0
    ind = CGPInd(cfg, read(args["ind"], String))
    reward = play_atari(ind, args["game"]; seed=args["seed"], render=true)
    println(reward)
else
    mutate(i::CGPInd) = goldman_mutate(cfg, i)
    fit(i::CGPInd) = play_atari(i, cfg.game)
    e = NSGA2Evolution{CGPInd}(cfg, fit)
    run!(e)
end
