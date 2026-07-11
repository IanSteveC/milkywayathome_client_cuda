typedef double real;
typedef int mwbool;
typedef enum
{
    InvalidDwarf = (-1),
    Plummer = 0,
    NFW = 1,
    General_Hernquist = 2,
    Einasto = 3,
    Cored = 4,
    King = 5
} dwarf_t;
typedef struct __attribute__((aligned))
{
    dwarf_t type;
    real mass;
    real scaleLength;
    real n;
    real p0;
    real r200;
    real ps, r1, rc;
    real W0, r_t, r_0, mu, rho0, rho1, sigma, phi0;
    real rcut, rdecay, pcut, delta, m_nfw_cut, gamma1, psi_nfw_cut, psi_cut_cut;
    real m_nfw_r1, m_iso_r1, psi_nfw_r1, psi_iso_r1;
    real mcut_pref;
} Dwarf;

NB_P1_QUAL real gammln(const real z)
{
    static __thread real gammln_last_z = -1.0e308;
    static __thread real gammln_last_v = 0.0;
    if (z == gammln_last_z) return gammln_last_v;
    real g = 4.7421875;
    real x, tmp, y, A_g;
    static const real coeff[14] = {57.1562356658629235,-59.5979603554754912,
                                14.1360979747417471,-0.491913816097620199,.339946499848118887e-4,
                                .465236289270485756e-4,-.983744753048795646e-4,.158088703224912494e-3,
                                -.210264441724104883e-3,.217439618115212643e-3,-.164318106536763890e-3,
                                .844182239838527433e-4,-.261908384015814087e-4,.368991826595316234e-5};
    y = x = z;
    tmp = x + g + 0.5;
    tmp = (x + 0.5) * log_rn(tmp) - tmp;
    A_g = 0.999999999999997092;
    for (int j = 0; j < 14; j++)
    {
        A_g += coeff[j] / ++y;
    }
    tmp += log_rn(2.5066282746310005 * A_g / x);
    return tmp;
}

NB_P1_QUAL static real gser(const real a, const real x, real* gln)
{
    const int itmax = 100;
    const real eps = (real) 3.0e-7;
    real sum, del, ap;
    *gln = gammln(a);
    if (x <= 0.0)
    {
        return 0.0;
    }
    ap = a;
    del = sum = 1.0 / a;
    for (int n = 1; n <= itmax; ++n)
    {
        ap += 1.0;
        del *= x / ap;
        sum += del;
        if (fabs(del) < fabs(sum) * eps)
        {
            return sum * exp_rn(-x + a * log_rn(x) - (*gln));
        }
    }
    fprintf(stderr, "WARNING: gser did not converge (a=%f, x=%f)\n", a, x);
    return sum * exp_rn(-x + a * log_rn(x) - (*gln));
}

NB_P1_QUAL static real gcf(const real a, const real x, real* gln)
{
    const int itmax = 100;
    const real eps = (real) 3.0e-7;
    const real fpmin = (real) 1.0e-30;
    real an, b, c, d, del, h;
    *gln = gammln(a);
    b = x + 1.0 - a;
    if (fabs(b) < fpmin)
    {
        b = fpmin;
    }
    c = 1.0 / fpmin;
    d = 1.0 / b;
    h = d;
    for (int i = 1; i <= itmax; ++i)
    {
        an = -(real) i * ((real) i - a);
        b += 2.0;
        d = an * d + b;
        if (fabs(d) < fpmin)
        {
            d = fpmin;
        }
        c = b + an / c;
        if (fabs(c) < fpmin)
        {
            c = fpmin;
        }
        d = 1.0 / d;
        del = d * c;
        h *= del;
        if (fabs(del - 1.0) < eps)
        {
            return exp_rn(-x + a * log_rn(x) - (*gln)) * h;
        }
    }
    fprintf(stderr, "WARNING: gcf did not converge (a=%f, x=%f)\n", a, x);
    return exp_rn(-x + a * log_rn(x) - (*gln)) * h;
}

NB_P1_QUAL real gammp(const real a, const real x)
{
    real gln;
    if (x < 0.0 || a <= 0.0)
    {
        fprintf(stderr, "WARNING: Invalid arguments in gammp (a=%f, x=%f)\n", a, x);
        return (__builtin_nanf (""));
    }
    if (x < (a + 1.0))
    {
        return gser(a, x, &gln);
    }
    return 1.0 - gcf(a, x, &gln);
}

NB_P1_QUAL real gammq(const real a, const real x)
{
    real gln;
    if (x < 0.0 || a <= 0.0)
    {
        fprintf(stderr, "WARNING: Invalid arguments in gammq (a=%f, x=%f)\n", a, x);
        return (__builtin_nanf (""));
    }
    if (x < (a + 1.0))
    {
        return 1.0 - gser(a, x, &gln);
    }
    return gcf(a, x, &gln);
}

NB_P1_QUAL real GammaFunc(const real z)
{
    return exp_rn(gammln(z));
}

NB_P1_QUAL real UpperIncompleteGammaFunc(real a, real x)
{
    return GammaFunc(a) * gammq(a, x);
}

NB_P1_QUAL real LowerIncompleteGammaFunc(real a, real x)
{
    return GammaFunc(a) * gammp(a, x);
}



NB_P1_QUAL static real plummer_den(const Dwarf* model, real r)
{
    const real mass = model->mass;
    const real rscale = model->scaleLength;
    return (3.0 / (4.0 * 3.14159265358979323846)) * (mass / ((rscale) * (rscale) * (rscale))) * (((real) 1.0 / (( sqrt((((1.0 + ((r / rscale) * (r / rscale)))) * ((1.0 + ((r / rscale) * (r / rscale)))) * ((1.0 + ((r / rscale) * (r / rscale)))) * ((1.0 + ((r / rscale) * (r / rscale)))) * ((1.0 + ((r / rscale) * (r / rscale))))) ) )))) ;
}

NB_P1_QUAL static real plummer_pot(const Dwarf* model, real r)
{
    const real mass = model->mass;
    const real rscale = model->scaleLength;
    return mass / sqrt(((r) * (r)) + ((rscale) * (rscale)));
}

NB_P1_QUAL static real nfw_den(const Dwarf* model, real r)
{
    const real rscale = model->scaleLength;
    const real p0 = model->p0;
    const real rcut = model->rcut;
    real R = r / rscale;
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wfloat-equal"
    if (rcut != 0.0) {
#pragma GCC diagnostic pop
        const real pcut = model->pcut;
        const real rdecay = model->rdecay;
        const real delta = model->delta;
        if (r > rcut) {
            return pcut * pow_rn(r / rcut, delta) * exp_rn(-(r - rcut) / rdecay);
        }
        else {
            return p0 * ((real) 1.0 / (R)) * ((real) 1.0 / (((1.0 + R) * (1.0 + R))));
        }
    }
    return p0 * ((real) 1.0 / (R)) * ((real) 1.0 / (((1.0 + R) * (1.0 + R))));
}

NB_P1_QUAL static real nfw_pot(const Dwarf* model, real r)
{
    const real rscale = model->scaleLength;
    const real p0 = model->p0;
    const real rcut = model->rcut;
    real R = r / rscale;
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wfloat-equal"
    if (rcut != 0.0) {
#pragma GCC diagnostic pop
        const real rdecay = model->rdecay;
        const real delta = model->delta;
        const real m_nfw_cut = model->m_nfw_cut;
        const real gamma1 = model->gamma1;
        if (r > rcut) {
            return (
                model->mcut_pref
                * (((gamma1 - UpperIncompleteGammaFunc(delta + 3, r / rdecay)) / r)
                + (UpperIncompleteGammaFunc(delta + 2, r / rdecay) / rdecay)) + m_nfw_cut / r
            );
        } else {
            const real psi_nfw_cut = model->psi_nfw_cut;
            const real psi_cut_cut = model->psi_cut_cut;
            const real m_nfw_cut = model->m_nfw_cut;
            return (4.0 * 3.14159265358979323846 * p0 * ((rscale) * (rscale) * (rscale)) * log_rn(1.0 + R) * ((real) 1.0 / (r))
                - psi_nfw_cut + psi_cut_cut + m_nfw_cut / rcut);
        }
    }
    return 4.0 * 3.14159265358979323846 * ((rscale) * (rscale)) * p0 * ((real) 1.0 / (R)) * log_rn(1.0 + R);
}

NB_P1_QUAL static real gen_hern_den(const Dwarf* model, real r)
{
    const real mass = model->mass;
    const real rscale = model->scaleLength;
    return ((real) 1.0 / (2.0 * 3.14159265358979323846)) * mass * rscale / ( r * ((r + rscale) * (r + rscale) * (r + rscale)));
}

NB_P1_QUAL static real gen_hern_pot(const Dwarf* model, real r)
{
    const real mass = model->mass;
    const real rscale = model->scaleLength;
    return mass / (r + rscale);
}

NB_P1_QUAL static real einasto_den(const Dwarf* model, real r)
{
    const real mass __attribute__((unused)) = model->mass;
    const real h = model->scaleLength;
    const real n = model->n;
    real coeff = 1.0 / ( 4.0 * 3.14159265358979323846 * ((h) * (h) * (h)) * n * GammaFunc(3.0 * n));
    real thing = pow_rn(r, ((real) 1.0 / (n)));
    return coeff * exp_rn(-thing);
}

NB_P1_QUAL static real einasto_pot(const Dwarf* model, real r)
{
    const real mass = model->mass;
    const real h = model->scaleLength;
    const real n = model->n;
    real coeff = mass / (h * r);
    real thing = pow_rn(r, 1.0 / n);
    real term1 = UpperIncompleteGammaFunc(3.0 * n, thing);
    real term2 = r * UpperIncompleteGammaFunc(2.0 * n, thing);
    real term = 1.0 - ( term1 + term2 ) / GammaFunc(3.0 * n);
    return coeff * term;
}

NB_P1_QUAL static real cored_den(const Dwarf* model, real r)
{
    const real r1 = model->r1;
    const real rcut = model->rcut;
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wfloat-equal"
    if (rcut != 0.0 && r > rcut)
    {
        const real pcut = model->pcut;
        const real delta = model->delta;
        const real rdecay = model->rdecay;
        return pcut * pow_rn(r / rcut, delta) * exp_rn(-(r - rcut) / rdecay);
    }
    else if (r <= r1)
    {
        const real p0 = model->p0;
        const real rc = model->rc;
        return p0 / (1.0 + ((r / rc) * (r / rc)));
    }
    else
    {
        const real ps = model->ps;
        const real rs = model->scaleLength;
        return ps / ((r / rs) * ((1.0 + r / rs) * (1.0 + r / rs)));
    }
#pragma GCC diagnostic pop
}

NB_P1_QUAL static real cored_pot(const Dwarf* model, real r)
{
    const real r1 = model->r1;
    const real p0 = model->p0;
    const real rc = model->rc;
    const real ps = model->ps;
    const real rs = model->scaleLength;
    const real rcut = model->rcut;
    const real m_iso_r1 = model->m_iso_r1;
    const real m_nfw_r1 = model->m_nfw_r1;
    const real m_nfw_cut = model->m_nfw_cut;
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wfloat-equal"
    if (rcut != 0.0 && r > rcut)
    {
        const real delta = model->delta;
        const real rdecay = model->rdecay;
        const real gamma1 = model->gamma1;
        return (
            model->mcut_pref
            * (((gamma1 - UpperIncompleteGammaFunc(delta + 3, r / rdecay)) * ((real) 1.0 / (r)))
            + (UpperIncompleteGammaFunc(delta + 2, r / rdecay) * ((real) 1.0 / (rdecay))))
            + ((m_nfw_cut + m_iso_r1 - m_nfw_r1) * ((real) 1.0 / (r)))
        );
    }
    else if (r <= r1)
    {
        const real p0 = model->p0;
        const real rc = model->rc;
        const real psi_iso_r1 = model->psi_iso_r1;
        const real psi_nfw_r1 = model->psi_nfw_r1;
        real psi = (
            -4.0 * 3.14159265358979323846 * p0 * ((rc) * (rc)) * ((log_rn(((rc) * (rc)) + ((r) * (r))) * ((real) 1.0 / (2.0))) + ((rc * atan_rn(r / rc) * ((real) 1.0 / (r)))))
            - psi_iso_r1 + psi_nfw_r1 + ((m_iso_r1 - m_nfw_r1) * ((real) 1.0 / (r1)))
        );
        if (rcut != 0.0) {
            const real psi_nfw_cut = model->psi_nfw_cut;
            const real psi_cut_cut = model->psi_cut_cut;
            psi += -psi_nfw_cut - ((m_iso_r1 - m_nfw_r1) * ((real) 1.0 / (rcut)))
                + psi_cut_cut + ((m_nfw_cut + m_iso_r1 - m_nfw_r1) * ((real) 1.0 / (rcut)));
        }
        return psi;
    }
    else
    {
        const real ps = model->ps;
        const real rs = model->scaleLength;
        real psi = (
            4.0 * 3.14159265358979323846 * ps * ((rs) * (rs) * (rs)) * ((real) 1.0 / (r)) * log_rn(1.0 + r / rs) + ((m_iso_r1 - m_nfw_r1) * ((real) 1.0 / (r)))
        );
        if (rcut != 0.0) {
            const real psi_nfw_cut = model->psi_nfw_cut;
            const real psi_cut_cut = model->psi_cut_cut;
            const real m_nfw_cut = model->m_nfw_cut;
            psi += -psi_nfw_cut - ((m_iso_r1 - m_nfw_r1) * ((real) 1.0 / (rcut)))
                + psi_cut_cut + ((m_nfw_cut + m_iso_r1 - m_nfw_r1) * ((real) 1.0 / (rcut)));
        }
        return psi;
    }
#pragma GCC diagnostic pop
}

NB_P1_QUAL static real king_pot(const Dwarf* model, real r) { (void)model; (void)r; return 0.0; /* King unsupported in phase-1 offload; host gates on type */ }

NB_P1_QUAL static real king_den(const Dwarf* model, real r) { (void)model; (void)r; return 0.0; /* King unsupported in phase-1 offload; host gates on type */ }

NB_P1_QUAL real get_potential(const Dwarf* model, real r)
{
    real pot_temp = 0.0;
    switch(model->type)
    {
        case Plummer:
            pot_temp = plummer_pot(model, r);
            break;
        case NFW:
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wfloat-equal"
            if (model->p0 == 0.0) {
#pragma GCC diagnostic pop
                set_model_params(model);
            }
            pot_temp = nfw_pot(model, r );
            break;
        case General_Hernquist:
            pot_temp = gen_hern_pot(model, r );
            break;
        case Einasto:
            printf("WARNING: Einsato dwarf currently has problems and should not be used \n");
            pot_temp = einasto_pot(model, r);
            break;
        case Cored:
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wfloat-equal"
            if (model->p0 == 0.0) {
#pragma GCC diagnostic pop
                set_model_params(model);
            }
            pot_temp = cored_pot(model, r);
            break;
        case King:
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wfloat-equal"
            if (model->r_0 == 0.0) {
#pragma GCC diagnostic pop
                set_model_params(model);
            }
            pot_temp = king_pot(model, r);
            break;
        case InvalidDwarf:
        default:
            do { fprintf(stderr, "Invalid dwarf type, %d\n", model->type); boinc_finish(1); } while (0);
    }
    return pot_temp;
}

NB_P1_QUAL real get_density(const Dwarf* model, real r)
{
    real den_temp = 0.0;
    switch(model->type)
    {
        case Plummer:
            den_temp = plummer_den(model, r);
            break;
        case NFW:
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wfloat-equal"
            if (model->p0 == 0.0) {
#pragma GCC diagnostic pop
                set_model_params(model);
            }
            den_temp = nfw_den(model, r );
            break;
        case General_Hernquist:
            den_temp = gen_hern_den(model, r );
            break;
        case Einasto:
            printf("WARNING: Einsato dwarf currently has problems and should not be used \n");
            den_temp = einasto_den(model, r);
            break;
        case Cored:
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wfloat-equal"
            if (model->p0 == 0.0) {
#pragma GCC diagnostic pop
                set_model_params(model);
            }
            den_temp = cored_den(model, r);
            break;
        case King:
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wfloat-equal"
            if (model->r_0 == 0.0) {
#pragma GCC diagnostic pop
                set_model_params(model);
            }
            den_temp = king_den(model, r);
            break;
        case InvalidDwarf:
        default:
            do { fprintf(stderr, "Invalid dwarf type, %d\n", model->type); boinc_finish(1); } while (0);
    }
    return den_temp;
}

NB_P1_QUAL static inline real potential( real r, const Dwarf* comp1, const Dwarf* comp2)
{
    real potential_light = get_potential(comp1, r);
    real potential_dark = get_potential(comp2, r);
    real potential_result = (potential_light + potential_dark);
    return (potential_result);
}

NB_P1_QUAL static inline real density( real r, const Dwarf* comp1, const Dwarf* comp2)
{
    real density_light = get_density(comp1, r);
    real density_dark = get_density(comp2, r);
    real density_result = (density_light + density_dark );
    return density_result;
}

NB_P1_QUAL real first_derivative(real (*func)(const Dwarf*, real), real x, const Dwarf* comp1)
{
    const real h = 0.001;
    real p1 = 1.0 * (*func)(comp1, (x - 2.0 * h));
    real p2 = - 8.0 * (*func)(comp1, (x - h) );
    real p3 = - 1.0 * (*func)(comp1, (x + 2.0 * h));
    real p4 = 8.0 * (*func)(comp1, (x + h));
    real denom = ((real) 1.0 / (12.0 * h));
    real deriv = (p1 + p2 + p3 + p4) * denom;
    return deriv;
}

NB_P1_QUAL static inline real second_derivative(real (*func)(const Dwarf*, real), real x, const Dwarf* comp1)
{
    const real h = 0.001;
    real p1 = - 1.0 * (*func)(comp1, (x + 2.0 * h));
    real p2 = 16.0 * (*func)(comp1, (x + h));
    real p3 = -30.0 * (*func)(comp1, (x));
    real p4 = 16.0 * (*func)(comp1, (x - h));
    real p5 = - 1.0 * (*func)(comp1, (x - 2.0 * h));
    real denom = ((real) 1.0 / (12.0 * h * h));
    real deriv = (p1 + p2 + p3 + p4 + p5) * denom;
    return deriv;
}

NB_P1_QUAL static real fun(real ri, const Dwarf* comp1, const Dwarf* comp2, real energy, mwbool isDark)
{
    real first_deriv_density = 0.0;
    real second_deriv_density = 0.0;
    real denominator = 0.0;
    real first_deriv_psi = first_derivative(get_potential, ri, comp1) + first_derivative(get_potential, ri, comp2);
    real second_deriv_psi = second_derivative(get_potential, ri, comp1) + second_derivative(get_potential, ri, comp2);
    if (!isDark) {
        first_deriv_density = first_derivative(get_density, ri, comp1);
        second_deriv_density = second_derivative(get_density, ri, comp1);
    } else {
        first_deriv_density = first_derivative(get_density, ri, comp2);
        second_deriv_density = second_derivative(get_density, ri, comp2);
    }
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wfloat-equal"
    if(first_deriv_psi == 0.0)
    {
#pragma GCC diagnostic pop
        first_deriv_psi = 1.0e-6;
    }
    real dsqden_dpsisq = second_deriv_density * ((real) 1.0 / (first_deriv_psi)) - first_deriv_density * second_deriv_psi * ((real) 1.0 / (((first_deriv_psi) * (first_deriv_psi))));
    real diff = fabs(energy - potential(ri, comp1, comp2));
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wfloat-equal"
    if(diff != 0.0)
    {
#pragma GCC diagnostic pop
        denominator = ( ((real) 1.0 / (sqrt(diff))) );
    }
    else
    {
        denominator = ( ((real) 1.0 / (sqrt(fabs(energy - potential(ri + 0.0001, comp1, comp2) )))) );
    }
    real func = dsqden_dpsisq * denominator;
    return func;
}

