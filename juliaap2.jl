using Pkg
Pkg.add([
    "DiscreteChoiceModels", "CSV", "DataFrames"])
    
using DiscreteChoiceModels, CSV, DataFrames

# 1. Carrega o dataset idêntico ao do mlogit no R
df = CSV.read("Koppelman.txt", DataFrame, 
              delim='\t', 
              quotechar='"', 
              stripwhitespace=true)

df.choice_bin = [x == "yes" ? 1.0 : 0.0 for x in df.choice]

df_fixed = unique(df[:, [:case, :distance, :income, :urban]], :case)

df_wide_cost   = unstack(df, :case, :alternative, :cost, renamecols=x -> "cost_" * x)
df_wide_intime = unstack(df, :case, :alternative, :intime, renamecols=x -> "intime_" * x)

df_choice = filter(row -> row.choice == 1, df)[:, [:case, :alternative]]
rename!(df_choice, :alternative => :choice)

df_final = innerjoin(df_fixed, df_wide_cost, df_wide_intime, df_choice, on=:case)

modelo_canada_socio = multinomial_logit(
    @utility(begin
        # Utilidades
        "air"   ~ α_air   + β_cost * cost_air   + β_intime * intime_air   + β_inc_air   * income + β_urb_air   * urban
        "train" ~ α_train + β_cost * cost_train + β_intime * intime_train + β_inc_train * income + β_urb_train * urban
        "bus"   ~ α_bus   + β_cost * cost_bus   + β_intime * intime_bus   + β_inc_bus   * income + β_urb_bus   * urban
        "car"   ~ α_car   + β_cost * cost_car   + β_intime * intime_car   + β_inc_car   * income + β_urb_car   * urban
        
        # Fixando Train como ref
        α_train     = 0, fixed
        β_inc_train = 0, fixed
        β_urb_train = 0, fixed
    end),
    :choice, 
    df_final
)

resultados = DataFrame(
    Parametro = String.(modelo_canada_socio.coefnames),
    Estimativa = vec(modelo_canada_socio.coefs),
    Erro_Padrao = sqrt.(diag(modelo_canada_socio.vcov))
)

