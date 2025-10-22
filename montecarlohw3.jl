import Pkg
Pkg.activate(@__DIR__)
Pkg.instantiate()
using Plots
using Random # random number generation
using Distributions # probability distributions and interface
using Statistics # basic statistical functions, including mean

#function for one step of river


function do_numerical(L, Δx, C0, B0, N0, ka, kn, kc, Cs, U)
    n = Int(L / Δx) # number of length steps
    C = zeros(n + 1)
    B = zeros(n + 1)
    N = zeros(n + 1)
    C[1] = C0
    B[1] = B0
    N[1] = N0
    for i = 1:n
        B[i+1] = B[i] * exp(-kc * Δx / U)
        N[i+1] = N[i] * exp(-kn * Δx / U)
        C[i+1] = C[i] + (Δx / U) * (ka * (Cs - C[i]) - kc * B[i] - kn * N[i])
    end
    return (C, B, N)
end

#flow calculations
function calculate_flow(Qr,Qw,DOr,Br, Nr, Cw,Bw,Nw)
    Q1 = Qr + Qw
    C0 = (Qr*DOr + Qw*Cw) / Q1
    B0 = (Qr*Br + Qw*Bw) / Q1
    N0 = (Qr*Nr + Qw*Nw) / Q1
    return C0,B0,N0
end
# function for multiple two sources
#L1 vs L2, flow 
function two_inputs(L1, L2, dx, ka, kn, kc, Cs, U, Qr,Qw1, Qw2,DOr,Br, Nr, Cw1,Bw1,Nw1,Cw2,Bw2,Nw2)
    #initial Flows
    C01, B01,N01 = calculate_flow(Qr,Qw1,DOr,Br, Nr, Cw1,Bw1,Nw1)
    C1, B1, N1 = do_numerical(L1, dx, C01, B01, N01, ka, kc, kn, Cs, U)
    C1 = 0.82*C1 #removal efficiency
    #second Flows
    C02, B02,N02 = calculate_flow(Qr,Qw2,DOr,Br, Nr, Cw2,Bw2,Nw2)
    #run simulation for 35 km (post second inflow)
    C2, B2, N2 = do_numerical(L2, dx, C02, B02, N02, ka, kc, kn, Cs, U)
    #remove overlapping value at 15 km
    C2 = C2[2:end]
    #combine the first 15 km with second 35 km
    combined = [C1;C2]
    return combined
end

#monte carlo set up
Random.seed!(1)
log_n = LogNormal(2,0.15)

n = 1000:1000:500000
avg_freq = zeros(500)
std_freq = zeros(500)

Qr = 100000.0
Qw1 = 10000.0
Qw2 = 15000.0
# DO, CBOD, NBOD concentrations (mg/L)
Cw1 = 5.0;   Cw2 = 5.0
Br = 5.0;   Bw1 = 50.0;  Bw2 = 45.0
Nr = 5.0;   Nw1 = 35.0;  Nw2 = 35.0
L1 = 15; L2 =35; dx = 0.5
U = 6.0        # velocity (km/day)
ka = 0.55      # reaeration rate
kc = 0.35      # CBOD decay
kn = 0.25      # NBOD decay
Cs = 10.0      # DO saturation


for trial in 1:length(n)
    log_samples = rand(log_n, n[trial])
    fail_counter = 0 #maybe change?
    for i in 1:n[trial]
         DOr = log_samples[i]
         do_conc = two_inputs(L1, L2, dx, ka, kn, kc, Cs, U, Qr,Qw1, Qw2,DOr,Br, Nr, Cw1,Bw1,Nw1,Cw2,Bw2,Nw2)
         fail = false
         fail = any(do_conc .< 4.0)  # More efficient than loop
        
        if fail
            fail_counter += 1
        end
    end
    avg_freq[trial] = fail_counter/n[trial]
end
print(avg_freq[end])

conf_intervals = zeros(length(n), 2)

for i in 1:length(n)
    se = sqrt(avg_freq[i] * (1 - avg_freq[i]) / n[i])
    conf_intervals[i, 1] = avg_freq[i] - 1.96 * se
    conf_intervals[i, 2] = avg_freq[i] + 1.96 * se
end

# Find convergence point
println("\n=== Results ===")
println("Final probability estimate: $(avg_freq[end])")
println("Final 95% CI: [$(conf_intervals[end, 1]), $(conf_intervals[end, 2])]")


plot(n,avg_freq, legend=:false)
ylabel!("Expected Value")
xlabel!("Sample Size")
title!("Sample Size Determination")
