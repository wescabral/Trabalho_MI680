### Julia

import Pkg
Pkg.add("DataFrames")
Pkg.add("Turing")   
Pkg.add("Optim")  
Pkg.add("Distributions") 
Pkg.add("LinearAlgebra")
Pkg.add("Random")
Pkg.add("CSV")

using DataFrames, Optim, Distributions, LinearAlgebra, Turing, Random, CSV

koppelman = CSV.read("Koppelman.txt", DataFrame, 
              delim='\t', 
              quotechar='"', 
              stripwhitespace=true)

mode_map = Dict("train" => 1, "air" => 2, "bus" => 3, "car" => 4)
koppelman.alt_idx = [mode_map[a] for a in koppelman.alternative]

gdf = groupby(koppelman, :case)
N_casos = length(gdf)

# Objetos para o Turing
cost_mat   = zeros(Float64, N_casos, 4)
intime_mat = zeros(Float64, N_casos, 4)
income_vec = zeros(Float64, N_casos)
urban_vec  = zeros(Float64, N_casos)
y_vec      = zeros(Int, N_casos)

for (i, sub_df) in enumerate(gdf)
    # Variáveis socioeconômicas (são iguais para todas as alternativas daquele caso)
    income_vec[i] = sub_df.income[1]
    urban_vec[i]  = sub_df.urban[1]
    
    # Preenche os atributos específicos de cada uma das 4 alternativas
    for row in eachrow(sub_df)
        alt = row.alt_idx
        cost_mat[i, alt]   = row.cost
        intime_mat[i, alt] = row.intime
        
        # Se 'choice == 1', salvamos qual foi a alternativa escolhida
        if row.choice == 1
            y_vec[i] = alt
        end
    end
end

logcost_mat   = log.(cost_mat .+ 1e-6)   # evitar log(0)
logintime_mat = log.(intime_mat .+ 1e-6)

function mnp_loglikelihood_log(params, logcost, logintime, income, urban, y; S=200)
    N = length(y)
    b_cost   = params[1]
    b_intime = params[2]
    a_air = params[3]; b_inc_air = params[4]; b_urb_air = params[5]
    a_bus = params[6]; b_inc_bus = params[7]; b_urb_bus = params[8]
    a_car = params[9]; b_inc_car = params[10]; b_urb_car = params[11]

    total_loglik = 0.0
    Random.seed!(123)
    errors = randn(N, 4, S)

    for i in 1:N
        chosen = y[i]
        sim_success = 0
        inc = income[i]; urb = urban[i]

        for s in 1:S
            u1 = b_cost*logcost[i,1] + b_intime*logintime[i,1] + errors[i,1,s]
            u2 = a_air + b_inc_air*inc + b_urb_air*urb + b_cost*logcost[i,2] + b_intime*logintime[i,2] + errors[i,2,s]
            u3 = a_bus + b_inc_bus*inc + b_urb_bus*urb + b_cost*logcost[i,3] + b_intime*logintime[i,3] + errors[i,3,s]
            u4 = a_car + b_inc_car*inc + b_urb_car*urb + b_cost*logcost[i,4] + b_intime*logintime[i,4] + errors[i,4,s]

            if argmax((u1,u2,u3,u4)) == chosen
                sim_success += 1
            end
        end
        prob = max(sim_success / S, 1e-6)
        total_loglik += log(prob)
    end
    return -total_loglik
end

# Chute inicial para os 11 parâmetros (todos zerados)
initial_guess = zeros(11)

println("Otimizando parâmetros via Máxima Verossimilhança (MNE)...")
res = optimize(
    p -> mnp_loglikelihood(p, cost_mat, intime_mat, income_vec, urban_vec, y_vec), 
    initial_guess, 
    BFGS(), # Algoritmo robusto livre de derivadas
    Optim.Options(iterations=500, show_trace=true)
)

res_log = optimize(
    p -> mnp_loglikelihood_log(p, logcost_mat, logintime_mat, income_vec, urban_vec, y_vec),
    initial_guess,
    BFGS(),
    Optim.Options(iterations=500, show_trace=true)
)

# Coeficientes estimados
estimated_coefficients = Optim.minimizer(res)
estimated_coefficients_log = Optim.minimizer(res_log)


labels = [
    "Beta Cost/LogCost", "Beta Intime/LogIntime",
    "Air: Constant", "Air: Income", "Air: Urban",
    "Bus: Constant", "Bus: Income", "Bus: Urban",
    "Car: Constant", "Car: Income", "Car: Urban"
]

println("\n--- COMPARAÇÃO MNP ---")
for (lbl, val_a, val_b) in zip(labels, estimated_coefficients, estimated_coefficients_log)
    println(rpad(lbl, 20), ": ",
            round(val_a, digits=4), "   |   ",
            round(val_b, digits=4))
end

println("\nLog-likelihood: ", -Optim.minimum(res))
println("Log-likelihood (modelo log): ", -Optim.minimum(res_log))
